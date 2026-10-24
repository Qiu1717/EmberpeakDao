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

func action(id: String) -> void:
	var event := InputEventAction.new()
	event.action = id
	event.pressed = true
	root.push_input(event, true)
	await frames(2)
	event = InputEventAction.new()
	event.action = id
	root.push_input(event, true)
	await frames(2)

func click(button: Button) -> void:
	await frames(2)
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

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/phase6/" + label + ".png")

func _run() -> void:
	var app: Node = root.get_node("App")
	var session: Node = root.get_node("Session")
	if "--restart" in OS.get_cmdline_user_args():
		await app.continue_game()
		await frames(12)
		var restored: Node = current_scene.world
		if not check(restored.medicine == 1 and restored.player.health == 65, "独立进程恢复剩余1次药品与65生命"):
			return
		if not check(restored.current_id == "entry" and session.profile.weapon_unlocks.has("po_shan"), "独立进程恢复NPC保存的房间与永久蓝图武器"):
			return
		if not check(restored.run.equipment_rewards.size() == 1 and restored.run.spirit == 20 and session.profile.subrealm == 2, "独立进程NPC快照不重复发装备或返还突破消耗"):
			return
		print("PHASE6_SERVICES_RESTART_OK")
		quit()
		return
	await app.start_new_game()
	await frames(12)
	var route: Node = current_scene.world
	var player: Node = route.player
	var ui: Node = current_scene.run_interface
	if not check(route.has_method("npc_action"), "首图具有实际NPC服务入口"):
		return
	if not check(route.medicine == 2 and not route.use_medicine().accepted and route.medicine == 2, "初始2次药品，满血不消耗"):
		return
	player.health = 40
	await action("heal")
	if not check(player.health == 75 and route.medicine == 1, "实际药品输入恢复35并消耗一次"):
		return
	if not check(route.use_medicine().accepted and player.health == 100 and route.medicine == 0 and not route.use_medicine().accepted, "药品不超过上限，耗尽不能再用"):
		return
	if not check(not route.npc_action("a_heng", "supply").accepted and route.medicine == 0, "远离阿蘅不能隔空补给"):
		return
	player.position = route.npc_point("shen_yan_zhou")
	await action("interact")
	if not check(ui.kind == "npc" and ui.payload.npc_id == "shen_yan_zhou" and paused, "沈砚舟近距离真实输入打开教学对话"):
		return
	await capture("shen_yan_zhou")
	await click(ui.get_node("%NpcPractice"))
	if not check(not paused and route.room.has_node("PracticeTarget"), "教学实际生成可攻击临时木桩并恢复世界输入"):
		return
	var target: Node = route.room.get_node("PracticeTarget")
	player.reset_motion_at(target.position - Vector2(60, 0))
	player.facing = 1
	await frames(4)
	await action("attack")
	await frames(20)
	if not check(target.health < 200 and route.run.spirit == 0, "教学木桩实际命中扣血，不发探索奖励"):
		return
	player.reset_motion_at(route.npc_point("gu_chang_geng"))
	await frames(4)
	await action("interact")
	if not check(ui.kind == "npc" and ui.payload.npc_id == "gu_chang_geng", "顾长庚可打开装备蓝图服务"):
		return
	await capture("gu_chang_geng")
	ui.close()
	if not check(not route.npc_action("gu_chang_geng", "blueprint", "po_shan").accepted and not session.profile.blueprints.has("po_shan"), "不能登记未持有的长枪蓝图"):
		return
	route.run.claim_enemy("npc_fixture", "mountain_general")
	await frames(6)
	var good_store: RefCounted = session.store
	session.store = load("res://scripts/save/save_file.gd").new("res://project.godot/save.json", load("res://scripts/save/snapshot_codec.gd").validate)
	if not check(not route.npc_action("gu_chang_geng", "blueprint", "po_shan").accepted and not session.profile.blueprints.has("po_shan"), "铁匠保存失败不提前登记蓝图或解锁"):
		return
	session.store = good_store
	if not check(route.npc_action("gu_chang_geng", "blueprint", "po_shan").accepted and session.profile.weapon_unlocks.has("po_shan"), "铁匠登记真实实物，永久解锁基础长枪"):
		return
	var revision: int = session.saved.revision
	if not check(not route.npc_action("gu_chang_geng", "blueprint", "po_shan").accepted and session.saved.revision == revision, "重复登记不重复提交或发奖"):
		return
	player.position = route.npc_point("a_heng")
	route.interact()
	await frames()
	if not check(ui.kind == "npc" and ui.payload.npc_id == "a_heng", "阿蘅具有真实补给对话入口"):
		return
	await capture("a_heng")
	ui.close()
	session.store = load("res://scripts/save/save_file.gd").new("res://project.godot/save.json", load("res://scripts/save/snapshot_codec.gd").validate)
	if not check(not route.npc_action("a_heng", "supply").accepted and route.medicine == 0, "补给写失败不提前增加药品"):
		return
	session.store = good_store
	route.interact()
	await frames()
	await click(ui.get_node("%NpcSupply"))
	if not check(route.medicine == 2 and session.saved.run_snapshot.medicine == 2, "鼠标补给实际补齐2次并保存继续快照"):
		return
	ui.close()
	player.health = 30
	route.use_medicine()
	if not check(route.medicine == 1 and player.health == 65, "补给所得药品真实可用"):
		return
	player.state = player.State.HURT
	if not check(not route.use_medicine().accepted and route.medicine == 1, "受击硬直不能使用药品取消"):
		return
	player.reset_motion_at(route.npc_point("a_heng"))
	var snapshot: Dictionary = route.capture_snapshot()
	if not check(session.commit_state(session.clone_profile(), snapshot).accepted, "剩余药量与生命一致保存"):
		return
	var codec: GDScript = load("res://scripts/save/snapshot_codec.gd")
	var bad: Dictionary = session.saved.duplicate(true)
	bad.run_snapshot.medicine = 3
	if not check(not codec.validate(bad), "非法超过2次的药品快照拒绝"):
		return
	bad.run_snapshot.erase("medicine")
	if not check(codec.validate(bad), "阶段5无药品字段的旧快照兼容"):
		return
	await app.return_to_menu()
	session.load_profile()
	await app.continue_game()
	await frames(12)
	route = current_scene.world
	player = route.player
	ui = current_scene.run_interface
	if not check(route.medicine == 1 and player.health == 65, "继续游戏恢复剩余药量和生命，不免费补满"):
		return
	route._load_node("altar", false)
	await frames(8)
	player.position = route.room.altar_point
	route.interact()
	if not check(ui.kind == "altar" and ui.body.get_child(0).text.contains("残灯婆婆") and route.medicine == 2, "残灯婆婆接原祭坛与药品休整"):
		return
	await capture("can_deng")
	ui.close()
	var shop_id: String = "side_before" if route.graph.nodes.side_before.kind == "shop" else "side_after"
	route._load_node(shop_id, false)
	await frames(6)
	player.position = route.interaction_point()
	route.interact()
	if not check(ui.kind == "shop" and ui.get_node("%Buy_talisman") != null, "无面商人真实商品及替劫符入口可用"):
		return
	await capture("faceless")
	ui.close()
	if not check(not paused and not app.modal_active, "各NPC及商店关闭后恢复输入"):
		return
	var position_before: float = player.position.x
	Input.action_press("move_right")
	await frames(12)
	Input.action_release("move_right")
	if not check(player.position.x > position_before + 10, "商店关闭后真实移动输入生效"):
		return
	print("PHASE6_SERVICES_PASSED=", checks)
	quit()
