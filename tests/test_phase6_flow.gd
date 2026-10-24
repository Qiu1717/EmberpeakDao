extends SceneTree
var checks := 0
var app: Node
var session: Node
var route: Node
var ui: Node
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("FAIL: " + message)
		quit(1)
		return false
	checks += 1
	print("PASS: " + message)
	return true
func frames(count: int = 4) -> void:
	for index in count:
		await physics_frame
	await process_frame

func click(button: Button, capture_label: String = "") -> void:
	# 新建模态需先完成容器布局，再按最终按钮坐标滚动。
	await frames(2)
	var ancestor: Node = button.get_parent()
	while ancestor != null and not ancestor is ScrollContainer:
		ancestor = ancestor.get_parent()
	if ancestor is ScrollContainer:
		ancestor.ensure_control_visible(button)
	await frames(2)
	if not capture_label.is_empty():
		await capture(capture_label)
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await frames()

func _run() -> void:
	app = root.get_node("App")
	session = root.get_node("Session")
	if "--completion-read" in OS.get_cmdline_user_args():
		await verify_completion()
		return
	if not check(app.has_method("return_to_home"), "完整流程包含真实驻地返回入口"):
		return
	await app.return_to_menu()
	await frames(6)
	if not check(current_scene.get_node("%Continue").disabled, "首次启动菜单无假继续"):
		return
	await capture("main_menu")
	await app.start_new_game()
	await frames(12)
	route = current_scene.world
	ui = current_scene.run_interface
	if not check(route.current_id == "entry" and route.player.health == 100, "新游戏进入首图炼气初期"):
		return
	if not check(not route.complete_exploration().accepted and not route.run.ended, "未击败Boss不能提前通关结算"):
		return
	# 使用真实连接和交互换房；仅通过receive_hit注入战斗伤害，不声称自然通关。
	await visit("melee")
	await clear_combat()
	await visit("entry")
	await visit("platform")
	await clear_combat()
	await visit("monument")
	route.player.position = route.interaction_point()
	route.interact()
	if not check(ui.kind == "event", "旧碑真实交互进入选择"):
		return
	ui._event("b")
	var spirit: int = route.run.spirit
	if not check(not route.resolve_event("b").accepted and route.run.spirit == spirit, "事件选择有实际灵气结果且不可重复领取"):
		return
	await visit("side_before")
	await side_room()
	await visit("archer")
	await clear_combat()
	await visit("side_after")
	await side_room()
	await visit("elite")
	await clear_combat()
	await visit("altar")
	route.player.position = route.room.altar_point
	route.interact()
	ui._altar("record", "")
	ui.close()
	if not check(session.profile.banked_stones > 0 and session.can_continue(), "祭坛记录真实探索所得并可继续"):
		return
	var seed: int = route.run.seed
	var run_id: String = route.run.run_id
	var upgrades: Dictionary = route.run.upgrades.duplicate(true)
	await app.return_to_menu()
	var saved_revision: int = session.saved.revision
	await app.return_to_home()
	await frames(8)
	if not check(session.can_continue() and session.saved.revision == saved_revision, "带有效探索进入驻地不覆盖快照"):
		return
	await click(current_scene.get_node("%HomeContinue"))
	await frames(12)
	route = current_scene.world
	ui = current_scene.run_interface
	if not check(route.current_id == "altar" and route.run.seed == seed and not route.run.upgrades.is_empty(), "菜单继续恢复房间、种子和局内强化"):
		return
	if not check(route.run.run_id == run_id and route.medicine == 2 and route.run.upgrades == upgrades, "驻地真实继续按钮恢复同一run_id、药品和强化"):
		return
	await visit("boss")
	var boss: Node = route.room.enemies[0]
	boss.state = boss.State.IDLE
	boss.receive_hit(600, Vector2.ZERO)
	if not check(boss.phase == 2 and boss.health == 500, "真实Boss受伤跨55%阈值切换二阶段"):
		return
	boss.state = boss.State.IDLE
	await clear_combat()
	if not check(route.run.materials.get("foundation_marrow", 0) == 1 and session.profile.boss_kills.has("mountain_general"), "Boss发放一份灵髓并永久记录首杀"):
		return
	var gun: Dictionary = route.inventory.items.filter(func(item): return item.item_id == "po_shan")[0]
	if not check(route.equip_item(gun.instance_id).accepted and route.player.weapon_id == "po_shan", "本次Boss武器奖励实际可装备"):
		return
	await visit("altar")
	route.player.position = route.room.altar_point
	if not check(route.altar_action("blueprint", "po_shan").accepted, "同一祭坛登记Boss武器蓝图"):
		return
	var banked: int = session.profile.banked_stones
	var pending_stones: int = route.run.stones
	var old_store: RefCounted = session.store
	session.store = load("res://scripts/save/save_file.gd").new("res://project.godot/save.json", load("res://scripts/save/snapshot_codec.gd").validate)
	if not check(not route.complete_exploration().accepted and not route.run.ended and session.profile.banked_stones == banked and route.run.stones == pending_stones, "结算写失败不记录资源、不清局，仍可重试"):
		return
	session.store = old_store
	route.interact()
	if not check(ui.has_node("%CompleteExploration"), "Boss后原祭坛显示真实结束结算入口"):
		return
	await click(ui.get_node("%CompleteExploration"), "completion")
	await frames(12)
	if not check(current_scene.scene_file_path == "res://scenes/world/home.tscn" and session.saved.run_snapshot == null and not session.can_continue(), "成功结算返回驻地并使磁盘旧探索失效"):
		return
	if not check(session.profile.banked_stones == banked + pending_stones and session.profile.banked_materials.get("foundation_marrow", 0) == 1 and session.profile.weapon_unlocks.has("po_shan"), "结算只记录一次资源，材料与解锁保留"):
		return
	if not check(not paused and not app.modal_active and current_scene.has_node("Actors/Player"), "驻地具有真实角色与可走地形，无残留暂停"):
		return
	await capture("home")
	if "--completion-write" in OS.get_cmdline_user_args():
		print("COMPLETION_WRITE_OK")
		quit()
		return
	await app.start_new_game()
	await frames(12)
	route = current_scene.world
	ui = current_scene.run_interface
	if not check(route.run.seed != seed and route.run.upgrades.is_empty() and route.run.equipment_rewards.is_empty() and route.inventory.items.size() == 2, "下一局新种子，无上局强化或掉落，仅有解锁基础武器"):
		return
	await visit("melee")
	await clear_combat()
	await visit("monument")
	await visit("archer")
	await clear_combat()
	await visit("elite")
	await clear_combat()
	await visit("altar")
	route.player.position = route.room.altar_point
	route.interact()
	await click(ui.get_node("%AltarBreakthrough"))
	if not check(session.profile.realm == 1 and session.profile.banked_materials.get("foundation_marrow", 0) == 0, "沿用上局已记录材料与实际两局灵气，在祭坛筑基并消耗灵髓"):
		return
	await capture("foundation")
	ui.close()
	var permanent: Dictionary = session.profile.to_dict()
	route.player.receive_hit(100000, Vector2.ZERO)
	await frames(55)
	if not check(route.run.ended and route.run.upgrades.is_empty() and route.inventory.items.is_empty() and session.profile.to_dict() == permanent and not session.can_continue(), "死亡清局内状态，筑基和已耗资源账本不回退"):
		return
	ui.get_node("%ReturnHome").pressed.emit()
	await frames(12)
	if not check(current_scene.scene_file_path.ends_with("home.tscn") and current_scene.player.stats.max_health == 115, "死亡总结可实际返回驻地，筑基基础属性保持"):
		return
	await app.start_new_game()
	await frames(12)
	if not check(current_scene.world.run.spirit == 0 and current_scene.world.player.stats.max_health == 115 and not paused, "死亡后再次开局干净且保留永久境界"):
		return
	print("PHASE6_FLOW_PASSED=", checks)
	quit()

func verify_completion() -> void:
	if not check(not session.can_continue() and session.saved.run_snapshot == null, "独立进程重启后通关旧局保持失效"):
		return
	if not check(session.profile.subrealm == 3 and session.profile.banked_spirit == 94 and session.profile.banked_materials.get("foundation_marrow", 0) == 1, "独立进程读取实际274灵气累计及记录灵髓"):
		return
	if not check(session.profile.weapon_unlocks.has("po_shan") and session.profile.boss_kills.has("mountain_general"), "独立进程读取通关蓝图武器和首杀"):
		return
	await app.start_new_game()
	await frames(12)
	route = current_scene.world
	if not check(route.run.upgrades.is_empty() and route.run.equipment_rewards.is_empty() and route.medicine == 2 and route.inventory.items.size() == 2, "通关后独立进程开启干净探索"):
		return
	print("COMPLETION_READ_OK")
	quit()

func visit(id: String) -> void:
	var backwards: bool = id in route.graph.nodes[route.current_id].previous
	route.player.reset_motion_at(route.room.entry_point if backwards else route.room.exit_point)
	route.interact()
	if ui.kind != "route" or not ui.payload.choices.any(func(node): return node.id == id):
		check(false, "真实路线可到达 " + id)
		return
	ui._travel(id)
	for enemy in route.room.enemies:
		enemy.set_physics_process(false)
	await frames(5)
	check(route.current_id == id, "沿有效门连接进入 " + id)

func clear_combat() -> void:
	for enemy in route.room.enemies:
		if is_instance_valid(enemy) and enemy.health > 0:
			enemy.state = enemy.State.IDLE
			enemy.receive_hit(100000, Vector2.ZERO)
	await frames(5)
	check(route.room.is_cleared, "真实敌人死亡后清场开门 " + route.current_id)
	if route.upgrade_pending.has(route.current_id):
		var options: Array = route.run.offer_upgrades(route.current_id)
		ui._choose(options[0])
		await frames(5)
		check(not route.upgrade_pending.has(route.current_id), "首次清场三选一真实生效 " + route.current_id)

func side_room() -> void:
	route.player.position = route.interaction_point()
	route.interact()
	if route.graph.nodes[route.current_id].kind == "shop":
		check(ui.kind == "shop", "商店实际可打开")
		route.player.health = maxi(1, route.player.health - 40)
		var before: int = route.run.stones + session.profile.banked_stones
		var result: Dictionary = route.buy("heal")
		check(result.accepted and route.run.stones + session.profile.banked_stones == before - 12, "商人购买实际治疗并扣12灵石")
		ui.close()
	else:
		var before: int = route.run.stones
		route.interact()
		check(route.run.stones == before and not route.run.equipment_rewards.is_empty(), "宝箱真实掉落装备，不重复领取")
	await frames(5)

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/phase6/" + label + ".png")
