extends SceneTree
var checks := 0
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
func click(button: Button) -> void:
	var ancestor: Node = button.get_parent()
	while ancestor != null and not ancestor is ScrollContainer:
		ancestor = ancestor.get_parent()
	if ancestor is ScrollContainer:
		ancestor.ensure_control_visible(button)
	await frames(2)
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
func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/phase5/" + name + ".png")
func _run() -> void:
	if not check(root.has_node("Session"), "正式工程挂载永久档案与存档服务"):
		return
	var app: Node = root.get_node("App")
	var session: Node = root.get_node("Session")
	await app.start_new_game()
	await frames(12)
	var route: Node = current_scene.world
	var player: Node = route.player
	var ui: Node = current_scene.run_interface
	# 通过真实奖励接口注入材料与灵气，隔离战斗时长；非自然通关证明。
	route.run.claim_enemy("fixture:boss", "mountain_general")
	await frames()
	if not check(session.profile.subrealm == 2 and route.run.spirit == 20 and player.stats.realm_multiplier == 1.04, "战斗灵气触发连续自动突破并保留溢出"):
		return
	if not check(session.can_continue() and session.saved.run_snapshot.run.spirit == 20, "自动突破同时提交境界、消耗和一致局内快照"):
		return
	var gun: Dictionary = route.inventory.items.filter(func(item): return item.item_id == "po_shan")[0]
	await click(ui.get_node("%Inventory"))
	await click(ui.get_node("%Item_" + str(route.inventory.items.find(gun))))
	await capture("equipment_detail")
	await click(ui.get_node("%EquipItem"))
	if not check(route.inventory.weapon_id() == "po_shan" and player.weapon_id == "po_shan" and player.stats.sword_damage[0] == 22, "背包详情实际鼠标装备长枪，改变真实基础伤害"):
		return
	ui.close()
	if not check(not session.altar_action(route, "breakthrough").accepted, "非祭坛拒绝大境界突破"):
		return
	# 测试夹具只挂载祭坛，原八模板路线可达性由既有探索测试覆盖。
	route._load_node("altar", false)
	await frames(12)
	player.position = route.room.altar_point
	route.run.claim_enemy("fixture:elite", "armored_xiao")
	await frames()
	if not check(session.profile.subrealm == 3 and route.run.spirit == 0, "达到炼气圆满但不自动跨大境界"):
		return
	for index in 5:
		if index == 0:
			route.run.rules = route.run.rules.duplicate(true)
			route.run.rules.chest.equipment_pool = ["hui_ling"]
		route.run.claim_chest("fixture:chest:" + str(index))
	await frames()
	var high_items: Array = route.inventory.items.filter(func(item): return item.item_id in ["hui_ling", "xuan_wen"])
	if not check(not high_items.is_empty() and not route.equip_item(high_items[0].instance_id).accepted, "炼气圆满不能装备已拾取的筑基装备"):
		return
	route.interact()
	await frames()
	if not check(ui.kind == "altar" and paused, "祭坛真实交互打开记录与突破界面"):
		return
	await capture("altar_before")
	await click(ui.get_node("%AltarRecord"))
	if not check(session.profile.banked_spirit == 100 and route.run.spirit == 0 and session.profile.banked_materials.get("foundation_marrow", 0) == 1, "祭坛结算全部未记录资源，材料记入永久余额"):
		return
	await click(ui.get_node("%AltarBreakthrough"))
	if not check(session.profile.realm == 1 and session.profile.subrealm == 0 and session.profile.banked_spirit == 0 and session.profile.banked_materials.get("foundation_marrow", 0) == 0 and player.stats.max_health == 115, "筑基消耗100灵气和一份灵髓，境界与生命实际生效"):
		return
	if not check(route.equip_item(high_items[0].instance_id).accepted and is_equal_approx(player.stats.qi_regen, 4.6), "筑基后同件玉佩可装备并实际增加真气恢复至4.6"):
		return
	ui.close()
	if not check(route.altar_action("blueprint", "po_shan").accepted and session.profile.weapon_unlocks.has("po_shan"), "祭坛登记蓝图并永久解锁已有长枪"):
		return
	var offers: Array = route.run.offer_upgrades("fixture:upgrade")
	route.run.choose_upgrade("fixture:upgrade", offers[0])
	await frames()
	if not check(not route.run.upgrades.is_empty(), "本局强化独立存在"):
		return
	route.altar_action("save")
	await app.return_to_menu()
	await frames(8)
	if not check(not current_scene.get_node("%Continue").disabled, "真实有效探索保存后主菜单继续可用"):
		return
	await click(current_scene.get_node("%Continue"))
	await frames(12)
	route = current_scene.world
	player = route.player
	ui = current_scene.run_interface
	if not check(route.current_id == "altar" and session.profile.realm == 1 and not route.run.upgrades.is_empty() and route.inventory.weapon_id() == "po_shan", "继续恢复境界、原房间、装备与局内强化快照"):
		return
	var banked_stones: int = session.profile.banked_stones
	player.receive_hit(100000, Vector2.ZERO)
	await frames(50)
	if not check(route.run.ended and route.run.upgrades.is_empty() and route.inventory.items.is_empty() and session.profile.realm == 1 and session.profile.weapon_unlocks.has("po_shan") and session.profile.banked_stones == banked_stones and not session.can_continue(), "死亡清局内实物和强化，保留永久境界解锁及已记录余额"):
		return
	await capture("death_summary")
	await app.start_new_game()
	await frames(12)
	route = current_scene.world
	if not check(route.player.stats.max_health == 115 and route.run.spirit == 0 and route.run.equipment_rewards.is_empty() and route.inventory.items.size() == 2, "新探索继承筑基和解锁基础武器，不继承掉落实物"):
		return
	print("PHASE5_FLOW_PASSED=", checks)
	quit()
