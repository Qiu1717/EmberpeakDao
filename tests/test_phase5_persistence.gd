extends SceneTree
## 各模式由外部依次启动独立进程；必须指定私有测试档，禁止读取正式游戏档。

const SaveFile := preload("res://scripts/save/save_file.gd")
const Codec := preload("res://scripts/save/snapshot_codec.gd")
const SOURCE := "fixture:persist"
const OFFER_SOURCE := "fixture:persist:offer"
var checks := 0
var failures := 0
var save_path := ""
var app: Node
var session: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> bool:
	checks += 1
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
	return ok

func frames(count: int = 4) -> void:
	for index in count:
		await physics_frame
	await process_frame

func _run() -> void:
	save_path = OS.get_environment("EMBERPEAK_SAVE_PATH")
	if not check(save_path.begins_with("user://phase5_persistence_") and save_path.ends_with("/save.json") and not save_path.contains(".."), "必填环境变量限制为本轮私有持久化测试目录"):
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if not check(args.size() == 1 and args[0] in ["--write", "--read", "--after-death", "--failures"], "明确选择一个持久化测试模式"):
		quit(1)
		return
	app = root.get_node("App")
	session = root.get_node("Session")
	print("PERSIST_PROCESS=", OS.get_process_id(), " MODE=", args[0], " PRIVATE_PATH=", save_path)
	match args[0]:
		"--write": await _write_mode()
		"--read": await _read_mode()
		"--after-death": await _after_death_mode()
		"--failures": await _failures_mode()
	if failures == 0:
		var marker: String = {"--write": "PERSIST_WRITE_OK", "--read": "PERSIST_READ_OK", "--after-death": "PERSIST_AFTER_DEATH_OK", "--failures": "PERSIST_FAILURES_OK"}[args[0]]
		print(marker, " CHECKS=", checks)
	quit(1 if failures else 0)

func _disk() -> Dictionary:
	return SaveFile.new(save_path, Codec.validate).load_save()

func same_json(actual: Variant, expected: Variant) -> bool:
	# 夹具JSON中的数值为float，生产恢复为int；两边都经过相同JSON数值语义比较。
	return JSON.parse_string(JSON.stringify(actual, "", true, true)) == JSON.parse_string(JSON.stringify(expected, "", true, true))

func _expectation_path() -> String:
	return save_path.get_base_dir().path_join("expectations.json")

func _write_expectations(data: Dictionary) -> bool:
	var file := FileAccess.open(_expectation_path(), FileAccess.WRITE)
	if not check(file != null, "期望值夹具只写入独立测试目录"):
		return false
	file.store_string(JSON.stringify(data, "", true, true))
	file.flush()
	var error := file.get_error()
	file.close()
	return check(error == OK, "跨进程期望值夹具完整落盘")

func _read_expectations() -> Dictionary:
	var file := FileAccess.open(_expectation_path(), FileAccess.READ)
	if not check(file != null, "独立进程能够读取上一进程的期望值夹具"):
		return {}
	var json := JSON.new()
	var parsed := json.parse(file.get_as_text())
	file.close()
	if not check(parsed == OK and json.data is Dictionary, "跨进程期望值夹具为完整字典"):
		return {}
	return json.data

func _to_altar(route: Node) -> void:
	# 隔离自然通关时长；本测试证明存档事务，不证明玩家已走通路线。
	route._load_node("altar", false)
	await frames(12)
	route.player.position = route.room.altar_point

func _write_mode() -> void:
	if not check(_disk().status == "missing", "写入进程从零文件首启，未复用旧测试档"):
		return
	await app.start_new_game()
	await frames(12)
	var route: Node = current_scene.world
	check(route.run.claim_enemy(SOURCE, "mountain_general").accepted, "通过真实奖励消费者获得120灵气、材料与长枪实物")
	await frames()
	check(session.profile.realm == 0 and session.profile.subrealm == 2 and route.run.spirit == 20, "连续自动突破至炼气后期，扣40与60后保留20")
	await _to_altar(route)
	if not check(route.altar_action("record").accepted, "祭坛真实记录资源并提交一致快照"):
		return
	check(session.profile.banked_spirit == 20 and session.profile.banked_stones == 80 and session.profile.banked_materials.get("foundation_marrow", 0) == 1, "已记录余额为20灵气、80灵石和一份筑基灵髓")
	var guns: Array = route.inventory.items.filter(func(item): return item.item_id == "po_shan")
	if not check(guns.size() == 1 and route.equip_item(guns[0].instance_id).accepted, "真实掉落长枪装备成功"):
		return
	check(not session.profile.blueprints.has("po_shan") and not session.profile.weapon_unlocks.has("po_shan"), "装备实物不会自动登记蓝图或永久解锁")
	var offers: Array = route.run.offer_upgrades(OFFER_SOURCE)
	check(offers.size() == 3, "生成待选择三选一并缓存其来源与候选")
	var chosen: Array = route.run.offer_upgrades("fixture:persist:chosen")
	check(chosen.size() == 3 and route.run.choose_upgrade("fixture:persist:chosen", chosen[0]), "另一个真实强化用于验证快照恢复及死亡清理")
	check(route.run.claim_enemy("fixture:unrecorded", "corpse").accepted, "额外奖励保持未记录，供死亡丢失验证")
	await frames()
	route.player.position = route.room.altar_point
	if not check(route.altar_action("save").accepted, "只保存完整探索快照，不把新增资源变成永久余额"):
		return
	check(session.profile.subrealm == 2 and session.profile.banked_spirit == 20 and route.run.spirit == 10 and route.run.stones == 5, "单独保存后已记录20与未记录10灵气各自保持")
	var disk := _disk()
	if not check(disk.accepted and disk.status == "loaded", "写入进程以完整生产语义校验再次读取成功"):
		return
	check(disk.data.run_snapshot.inventory.equipped.weapon == guns[0].instance_id, "磁盘快照确实包含装备实物ID")
	_write_expectations({"writer_pid": OS.get_process_id(), "profile": session.profile.to_dict(), "run": route.run.to_dict(), "inventory": route.inventory.to_dict(), "visited": route.visited.duplicate(true), "cleared_rooms": route.cleared_rooms.duplicate(true), "offers": offers, "gun_instance": guns[0].instance_id})

func _read_mode() -> void:
	var expected := _read_expectations()
	if expected.is_empty():
		return
	check(int(expected.writer_pid) != OS.get_process_id(), "读取发生于与写入不同的Godot进程")
	check(not session.blocked and session.profile.realm == 0 and session.profile.subrealm == 2 and session.profile.banked_spirit == 20 and session.can_continue(), "全新进程从磁盘恢复炼气后期、20永久灵气及继续能力")
	await app.continue_game()
	await frames(12)
	var route: Node = current_scene.world
	check(route.run.run_id == expected.run.run_id and route.current_id == "altar", "继续恢复原run_id与祭坛房间")
	check(route.visited == expected.visited and route.cleared_rooms == expected.cleared_rooms, "访问与清场标记跨进程完整恢复")
	check(route.inventory.to_dict() == expected.inventory and route.player.weapon_id == "po_shan" and route.inventory.equipped.weapon == expected.gun_instance, "完整装备实物、槽位及真实长枪战斗配置跨进程恢复")
	check(same_json(session.profile.to_dict(), expected.profile) and same_json(route.run.materials, expected.run.materials), "完整永久材料与未记录材料恢复，未合并账本")
	var state: Dictionary = route.run.to_dict()
	check(state.drop_rng_state == expected.run.drop_rng_state and state.upgrade_rng_state == expected.run.upgrade_rng_state, "掉落和候选随机流的完整状态恢复")
	check(route.run.offer_upgrades(OFFER_SOURCE) == expected.offers and route.run.to_dict().upgrade_rng_state == state.upgrade_rng_state, "同来源候选不重抽且不推进随机流")
	check(same_json(route.run.upgrades, expected.run.upgrades) and not route.run.upgrades.is_empty(), "已选择的局内强化跨进程恢复")
	var before: Dictionary = route.run.to_dict()
	check(not route.run.claim_enemy(SOURCE, "mountain_general").accepted and route.run.to_dict() == before, "已领取来源重放不能增加资源、材料、实物或推进随机流")
	check(route.player.receive_hit(100000, Vector2.ZERO), "真实受击进入死亡流程")
	await frames(50)
	check(route.run.ended and route.run.spirit == 0 and route.run.stones == 0 and route.run.materials.is_empty() and route.run.upgrades.is_empty() and route.inventory.items.is_empty(), "死亡清理未记录余额、材料、强化和全部装备实物")
	check(route.death_summary.spirit == 10 and route.death_summary.stones == 5 and same_json(route.death_summary.materials, expected.run.materials), "死亡摘要记录本次实际丢失的未记录资源")
	check(same_json(session.profile.to_dict(), expected.profile) and session.profile.subrealm == 2 and session.profile.banked_spirit == 20, "死亡保留已保存境界、已记录且未消耗余额与材料")
	var disk := _disk()
	check(not session.pending_death and not session.can_continue() and disk.accepted and disk.data.run_snapshot == null, "死亡成功持久化旧探索失效，重启无法继续旧局")
	expected["reader_pid"] = OS.get_process_id()
	_write_expectations(expected)

func _after_death_mode() -> void:
	var expected := _read_expectations()
	if expected.is_empty():
		return
	check(OS.get_process_id() != int(expected.writer_pid) and OS.get_process_id() != int(expected.reader_pid), "死亡后验证使用第三个独立Godot进程")
	check(same_json(session.profile.to_dict(), expected.profile) and session.profile.subrealm == 2 and session.profile.banked_spirit == 20, "第三进程确认境界及永久余额已落盘保留")
	check(not session.blocked and not session.pending_death and not session.can_continue() and session.saved.run_snapshot == null, "第三进程仍不能继续已死亡探索")
	await app.start_new_game()
	await frames(12)
	var route: Node = current_scene.world
	check(route.run.run_id != expected.run.run_id and route.player.stats.realm_multiplier == 1.04 and route.player.stats.max_health == 108, "新探索生成独立run_id并继承炼气后期真实属性")
	check(route.inventory.items.size() == 1 and route.inventory.items[0].item_id == "qing_feng" and route.inventory.weapon_id() == "qing_feng", "未登记蓝图的掉落长枪不免费带入新局，只给基础剑")
	check(route.run.spirit == 0 and route.run.stones == 0 and route.run.materials.is_empty() and route.run.equipment_rewards.is_empty() and route.run.upgrades.is_empty(), "新探索不继承旧局奖励、资源和强化")
	check(session.profile.banked_spirit == 20 and session.profile.banked_stones == 80 and session.profile.banked_materials.get("foundation_marrow", 0) == 1, "开启新局不清除已记录余额与材料")

func _failures_mode() -> void:
	if not check(_disk().status == "missing", "写失败测试使用另一个全新私有存档目录"):
		return
	await app.start_new_game()
	await frames(12)
	var route: Node = current_scene.world
	await _to_altar(route)
	if not check(route.altar_action("save").accepted, "写失败前先实际建立有效的原始快照"):
		return
	var original_revision: int = session.saved.revision
	var good_store: RefCounted = session.store
	var occupied := save_path.get_base_dir().path_join("blocked-save")
	check(DirAccess.make_dir_recursive_absolute(occupied) == OK, "真实目录占用存档目标，不模拟返回值")
	session.store = SaveFile.new(occupied, Codec.validate)
	check(route.run.claim_enemy("fixture:write_failure", "mountain_general").accepted, "写失败环境下通过真实奖励达到连续突破门槛")
	await frames()
	check(session.profile.realm == 0 and session.profile.subrealm == 0 and route.run.spirit == 120 and route.player.stats.max_health == 100, "保存失败不发布候选境界，不扣局内120灵气，不增加属性")
	check(session.message.contains("保存失败") and route.last_reward.contains("保存失败"), "保存失败向Session与探索界面提供明确反馈")
	var disk := _disk()
	check(disk.accepted and disk.data.revision == original_revision and disk.data.profile.subrealm == 0 and disk.data.run_snapshot.run.spirit == 0, "保存失败保留磁盘原有效事务，未发布失败奖励候选")
	session.store = good_store
	route._settle_growth()
	await frames()
	check(session.profile.subrealm == 2 and route.run.spirit == 20 and session.saved.revision == original_revision + 1, "恢复真实存储后重试成功，只扣40与60各一次")
	var successful_revision: int = session.saved.revision
	route._settle_growth()
	await frames()
	check(route.run.spirit == 20 and session.profile.subrealm == 2 and session.saved.revision == successful_revision, "重复成长结算不重复消耗或凭空追加提交")
	route.player.position = route.room.altar_point
	if not check(route.altar_action("record").accepted, "重试后可正常记录20灵气、80灵石和突破材料"):
		return
	var shop_id := ""
	for id in route.graph.nodes:
		if route.graph.nodes[id].kind == "shop":
			shop_id = id
	if not check(not shop_id.is_empty(), "从真实随机图找出无面商人节点"):
		return
	route._load_node(shop_id, false)
	await frames(12)
	check(route.buy("attack").accepted and session.profile.banked_stones == 60 and route.run.stones == 0, "商店实际花费20已记录灵石并扣减永久余额")
	session.load_profile()
	check(session.profile.banked_stones == 60 and session.saved.run_snapshot.run.shops[shop_id].attack == 0, "实际重新读档不返还已记录消耗，商品库存也不回滚")
	check(not route.buy("attack").accepted and session.profile.banked_stones == 60, "读档后同一已售罄商品不能重复购买或重复扣款")
	await _to_altar(route)
	check(route.run.claim_enemy("fixture:pending_death", "corpse").accepted, "死亡失败用例包含真实未记录余额")
	await frames()
	route.player.position = route.room.altar_point
	if not check(route.altar_action("save").accepted and session.can_continue(), "死亡失败前真实保存仍然可继续的活跃快照"):
		return
	var profile_before: Dictionary = session.profile.to_dict()
	var dead_run_id: String = route.run.run_id
	session.store = SaveFile.new(occupied, Codec.validate)
	check(route.player.receive_hit(100000, Vector2.ZERO), "目标不可写时通过真实伤害触发死亡")
	await frames(50)
	check(session.pending_death and not session.can_continue() and route.run.ended and route.run.spirit == 0 and route.run.upgrades.is_empty() and route.inventory.items.is_empty(), "死亡保存失败仍立即清局内内容，同时标记待重试并禁用继续")
	disk = _disk()
	check(disk.accepted and disk.data.run_snapshot != null and session.message.contains("死亡结算保存失败"), "旧磁盘快照未被假称失效，界面明确提示死亡结算失败")
	var dead_scene: Node = current_scene
	await app.start_new_game()
	await frames(2)
	check(current_scene == dead_scene and session.pending_death, "死亡结算待重试时App拒绝开始新探索")
	await app.return_to_menu()
	await frames(2)
	check(current_scene == dead_scene and session.pending_death, "死亡结算待重试时App拒绝返回菜单")
	var ui: Node = current_scene.run_interface
	ui.close()
	check(ui.kind == "death" and ui.modal.visible and app.modal_active, "死亡写失败不能关闭唯一重试入口")
	var pause := InputEventAction.new()
	pause.action = "pause"
	pause.pressed = true
	Input.parse_input_event(pause)
	await frames(2)
	pause.pressed = false
	Input.parse_input_event(pause)
	await frames(2)
	check(ui.kind == "death" and ui.modal.visible and app.modal_active, "Esc不能绕过死亡保存失败重试面板")
	session.store = good_store
	ui.get_node("%RetryDeath").pressed.emit()
	disk = _disk()
	check(not session.pending_death and not session.can_continue() and disk.accepted and disk.data.run_snapshot == null, "恢复存储并重试死亡后成功使旧快照在磁盘失效")
	check(session.profile.to_dict() == profile_before and session.profile.banked_stones == 60, "死亡重试不返还商店已花余额，也不重复修改永久档案")
	await app.start_new_game()
	await frames(12)
	route = current_scene.world
	check(route.run.run_id != dead_run_id and not route.run.ended and route.inventory.items.size() == 1 and route.inventory.weapon_id() == "qing_feng", "死亡重试成功后才能开启干净新探索")
	check(session.profile.subrealm == 2 and session.profile.banked_spirit == 20 and session.profile.banked_stones == 60 and route.run.spirit == 0, "新局保留永久成长及已扣余额，不继承未记录资源")
