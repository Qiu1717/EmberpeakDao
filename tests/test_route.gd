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
func frames(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame
func interact() -> void:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event.pressed = false
	Input.parse_input_event(event)
	await frames(3)
func _run() -> void:
	if not check(ResourceLoader.exists("res://scenes/rooms/sword_entry.tscn"), "六房间路线入口存在"):
		return
	root.get_node("App").start_new_game()
	await frames(15)
	var route: Node = current_scene.get_node("World/SwordRoute")
	var player: Node = route.player
	var rewards: Array[Dictionary] = []
	route.reward_requested.connect(func(payload: Dictionary): rewards.append(payload))
	for index in 6:
		if not check(route.room_index == index and player.is_on_floor(), "房间%d实际加载且入口落地" % index):
			return
		if index == 5:
			await frames(70)
		var room: Node = route.room
		if not check(room.platforms.size() > 0 and room.get_node("ExitGate") != null, "房间%d有平台与实体门" % index):
			return
		player.position = Vector2(room.platforms[0].position.x + 40, 640)
		player.velocity = Vector2.ZERO
		var jump := InputEventAction.new()
		jump.action = "jump"
		jump.pressed = true
		Input.parse_input_event(jump)
		await frames(2)
		jump.pressed = false
		Input.parse_input_event(jump)
		await frames(60)
		if not check(player.is_on_floor() and absf(player.position.y - room.platforms[0].position.y) < 2, "房间%d实际跳上平台并站立" % index):
			return
		if room.alive > 0:
			player.position = Vector2(1930, 640)
			player.velocity = Vector2.ZERO
			var move := InputEventAction.new()
			move.action = "move_right"
			move.pressed = true
			Input.parse_input_event(move)
			await frames(30)
			move.pressed = false
			Input.parse_input_event(move)
			if not check(player.position.x < 1990, "房间%d锁门实体阻挡角色" % index):
				return
			player.position = Vector2(2040, 640)
			player.velocity = Vector2.ZERO
			await interact()
			if not check(route.room_index == index and not room.is_cleared, "房间%d未清场不能切换" % index):
				return
			var notices := [0]
			room.cleared.connect(func(_id: String): notices[0] += 1)
			for enemy in room.enemies:
				# 等入场后通过真实受伤接口注入致死量，非正常战斗通关测试。
				enemy.receive_hit(100000, Vector2.ZERO)
				enemy.receive_hit(100000, Vector2.ZERO)
			await frames(3)
			if not check(room.is_cleared and notices[0] == 1 and room.get_node("ExitGate/CollisionShape2D").disabled, "房间%d死亡清场只通知一次并解除实体锁" % index):
				return
		if DisplayServer.get_name() != "headless":
			player.position = Vector2(350, 640)
			player.get_node("Camera2D").reset_smoothing()
			await frames(4)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://builds/phase3/room_%d.png" % index)
		if index < 5:
			player.health = 80
			player.position = Vector2(2060, 640)
			await interact()
			await frames(12)
			if not check(player.health == 80 and route.room_index == index + 1 and player.state != player.State.ATTACK, "房间%d出口真实F输入切换且保留生命清动作" % index):
				return
	var boss_rewards := rewards.filter(func(item: Dictionary): return item.enemy_id == "mountain_general")
	if not check(boss_rewards.size() == 1 and boss_rewards[0].guaranteed_material == "筑基灵髓" and not boss_rewards[0].drop_rates_defined, "Boss死亡唯一材料事件且未伪造随机掉率"):
		return
	player.position = Vector2(140, 640)
	await interact()
	await frames(12)
	if not check(route.room_index == 4 and route.room.is_cleared, "Boss后返回同一灵脉祭坛"):
		return
	player.health = 50
	player.position = Vector2(1000, 640)
	await interact()
	if not check(player.health == 100, "祭坛测试休整恢复生命"):
		return
	var old_count: int = rewards.size()
	player.position = Vector2(2060, 640)
	await interact()
	await frames(12)
	if not check(route.room_index == 5 and route.room.enemies.is_empty() and rewards.size() == old_count, "重访Boss房无重复敌人或奖励"):
		return
	root.get_node("App").start_new_game()
	await frames(15)
	route = current_scene.get_node("World/SwordRoute")
	if not check(route.room_index == 0 and route.player.health == 100 and route.cleared_rooms.size() == 1, "重新开始完整路线清理战斗和清场状态"):
		return
	print("ROUTE_CHECKS_PASSED=", checks)
	quit()
