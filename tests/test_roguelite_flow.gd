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
func tap(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)
func click(button: Button) -> void:
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
	await frames(2)
func clear_room(route: Node) -> void:
	# 调用真实伤害接口完成流程验证，不代表无辅助通关。
	await frames(75 if route.current_id == "boss" else 2)
	for enemy in route.room.enemies:
		enemy.receive_hit(100000, Vector2.ZERO)
	await frames()
func screenshot(id: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/phase4/" + id + ".png")
func _run() -> void:
	if not check(ResourceLoader.exists("res://scenes/world/roguelite_game.tscn"), "肉鸽游戏场景存在"):
		return
	var app: Node = root.get_node("App")
	app.start_new_game()
	await frames(18)
	var route: Node = current_scene.world
	var ui: Node = current_scene.run_interface
	var player: Node = route.player
	if not check(route.current_id == "entry" and route.run.spirit == 0 and player.is_on_floor(), "新游戏进入独立局内状态与实际碰撞入口"):
		return
	var first_seed: int = route.run.seed
	player.position = route.room.exit_point
	await tap("interact")
	if not check(app.modal_active and paused and ui.kind == "route", "出口交互打开路线选择并冻结世界"):
		return
	await screenshot("route_choices")
	await click(ui.get_node("%Route_melee"))
	await frames(18)
	if not check(route.current_id == "melee" and not paused and not app.modal_active, "路线按钮进入战斗房并恢复输入"):
		return
	if not check(not route.travel_to("monument"), "未清场不能离开战斗房"):
		return
	await clear_room(route)
	if not check(route.run.spirit > 0 and route.run.stones > 0 and ui.kind == "upgrade" and paused, "真实敌人死亡到账并触发首次清场三选一"):
		return
	var options: Array = route.run.offer_upgrades(route.current_id)
	if not check(options.size() == 3, "强化呈现三个不同候选"):
		return
	await screenshot("upgrade_choices")
	await tap("pause")
	if not check(not paused and not app.modal_active and app.state == app.State.PLAYING, "强化弹窗关闭不会误开暂停菜单"):
		return
	await tap("interact")
	if not check(route.run.offer_upgrades(route.current_id) == options and ui.kind == "upgrade", "关闭重开候选保持一致"):
		return
	await click(ui.get_node("%Upgrade_" + options[0]))
	await frames()
	if not check(not paused and route.run.upgrades.get(options[0], 0) == 1 and not route.choose_upgrade(options[0]), "选择生效一次且无法重复领取"):
		return
	var expected: Dictionary = route.run.stat_modifiers()
	if not check(is_equal_approx(player.stats.sword_damage[0], 14.0 * expected.attack_multiplier) and player.stats.max_health == 100 + expected.health_bonus, "强化实际写入战斗属性"):
		return
	# 探索另一入口支路，靠真实击杀收入覆盖商店价格，不注入测试灵石。
	if not check(route.travel_to("entry") and route.travel_to("platform"), "可回访入口并探索另一战斗分支"):
		return
	await frames(16)
	await clear_room(route)
	var platform_options: Array = route.run.offer_upgrades("platform")
	await click(ui.get_node("%Upgrade_" + platform_options[0]))
	await frames()
	var hp_before: int = player.health
	if not check(route.travel_to("monument"), "清场后可进入旧碑奇遇"):
		return
	await frames(16)
	player.position = route.interaction_point()
	await tap("interact")
	if not check(ui.kind == "event" and paused, "旧碑交互呈现实际事件选择"):
		return
	await screenshot("monument_event")
	await click(ui.get_node("%Event_a"))
	await frames()
	if not check(player.health == hp_before - int(floor(hp_before * 0.15)) and is_equal_approx(player.stats.sword_damage[0], 14.0 * route.run.stat_modifiers().attack_multiplier), "残剑问心实际扣当前生命并增加本局攻击"):
		return
	var spirit_before: int = route.run.spirit
	if not check(not route.resolve_event("b").accepted and route.run.spirit == spirit_before, "同一奇遇不能选择第二次或重复发奖"):
		return
	await tap("interact")
	if not check(not paused and ui.kind == "", "已完成的奇遇显示完成状态，不再次提供选择"):
		return
	# 沿实际图走完可选支路与关键节点；每次都经过合法连接。
	for destination in ["side_before", "archer", "side_after", "elite", "altar", "boss"]:
		if not check(route.travel_to(destination), "连接有效：" + destination):
			return
		await frames(16)
		var kind: String = route.graph.nodes[destination].kind
		if kind == "shop":
			player.health = mini(player.health, player.stats.max_health - 40)
			player.position = route.interaction_point()
			await tap("interact")
			if not check(ui.kind == "shop" and paused, "无面商人显示实际库存和价格"):
				return
			await screenshot("merchant")
			var old_stones: int = route.run.stones
			var old_hp: int = player.health
			await click(ui.get_node("%Buy_heal"))
			if not check(route.run.stones == old_stones - 12 and player.health == mini(player.stats.max_health, old_hp + 35), "商品扣灵石且治疗即时生效"):
				return
			ui.close()
		elif kind == "reward":
			player.position = route.interaction_point()
			await tap("interact")
			var equipment_count: int = route.run.equipment_rewards.size()
			await tap("interact")
			if not check(equipment_count > 0 and route.run.equipment_rewards.size() == equipment_count, "宝箱生成实际装备掉落实例且只能打开一次"):
				return
		elif kind in ["combat", "elite", "boss"]:
			await clear_room(route)
			var choices: Array = route.run.offer_upgrades(destination)
			if not choices.is_empty():
				await click(ui.get_node("%Upgrade_" + choices[0]))
			await frames()
		elif kind == "altar":
			player.position = route.room.altar_point
			await tap("interact")
			if not check(player.health == player.stats.max_health, "同一祭坛恢复生命"):
				return
	if not check(route.run.materials.get("foundation_marrow", 0) == 1, "Boss结算一份筑基灵髓"):
		return
	if not check(route.travel_to("altar"), "Boss后能返回原祭坛"):
		return
	await frames(16)
	if not check(route.travel_to("boss"), "可以回访已清Boss房"):
		return
	await frames(16)
	if not check(route.room.enemies.is_empty() and route.run.materials.get("foundation_marrow", 0) == 1 and not paused, "回访不重刷敌人、材料或强化"):
		return
	# 实际受伤导致死亡，强化和未记录资源同步清除。
	player.receive_hit(100000, Vector2.ZERO)
	await frames()
	if not check(route.run.ended and route.run.spirit == 0 and route.run.stones == 0 and route.run.upgrades.is_empty() and route.run.materials.is_empty() and route.run.equipment_rewards.is_empty(), "死亡清空所有局内成长"):
		return
	if not check(player.health == 0 and player.stats.sword_damage[0] == 14.0 and not route.travel_to("altar"), "死亡不能切房且战斗属性恢复基准"):
		return
	await screenshot("death")
	app.start_new_game()
	await frames(18)
	route = current_scene.world
	if not check(route.run.seed != first_seed and not route.run.ended and route.run.upgrades.is_empty() and route.player.health == 100 and route.visited.size() == 1, "重新开始生成新种子且无上局残留"):
		return
	await tap("pause")
	if not check(paused and app.state == app.State.PAUSED, "局内面板关闭后普通暂停仍正常"):
		return
	app.return_to_menu()
	await frames(12)
	if not check(not paused and not app.modal_active and current_scene.get_node("%Continue").disabled, "返回主菜单恢复输入且继续游戏保持诚实禁用"):
		return
	print("ROGUELITE_FLOW_PASSED=", checks)
	quit()
