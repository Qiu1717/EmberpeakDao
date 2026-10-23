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
func jump() -> void:
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
func _run() -> void:
	root.get_node("App").start_new_game()
	await frames(15)
	var route: Node = current_scene.get_node("World/SwordRoute")
	var player: Node = route.player
	for index in 6:
		route.enter_room(index)
		await frames(15)
		var room: Node = route.room
		if not check(room.get_node_or_null("PaintedMap") != null and room.get_node_or_null("Ground") == null and room.get_node_or_null("Platform0") == null, "房间%d使用原图世界关卡且移除旧平面" % index): return
		if not check(player.is_on_floor() and player.position.distance_to(room.entry_point) < 3, "房间%d出生点落在图中表面" % index): return
		var art: Node = room.map.get_node("Gameplay0")
		if not check(art is Polygon2D and art.polygon == art.uv and room.map.get_node("Ground0/CollisionPolygon2D").polygon == art.polygon, "房间%d纹理UV与实体轮廓同世界坐标" % index): return
		for enemy in room.enemies:
			enemy.set_physics_process(false)
		if index != 2:
			Input.action_press("move_right")
			await frames(70)
			Input.action_release("move_right")
			await frames(15)
			if not check(player.is_on_floor() and player.position.x > room.entry_point.x + 250 and absf(player.position.y - room.map.floor_at(player.position.x)) < 3, "房间%d通过真实移动沿原图地形行走" % index): return
	# 断阶第一跳：按原数值使用已有离台容错，跨145像素裂隙并升高110像素。
	route.enter_room(2)
	await frames(15)
	for enemy in route.room.enemies: enemy.set_physics_process(false)
	player.reset_motion_at(Vector2(740, 690))
	await frames(5)
	Input.action_press("move_right")
	for index in 60:
		await frames(1)
		if player.position.x >= 881: break
	await jump()
	await frames(35)
	Input.action_release("move_right")
	await frames(10)
	print("FIRST_LANDING=", player.position)
	if not check(player.is_on_floor() and player.position.x > 1010 and player.position.x < 1245 and absf(player.position.y - 580) < 2, "现有速度跳力真实跨越断桥首跳并落中岛"): return
	Input.action_press("move_right")
	for index in 60:
		await frames(1)
		if player.position.x >= 1220: break
	await jump()
	await frames(40)
	Input.action_release("move_right")
	await frames(15)
	if not check(player.is_on_floor() and player.position.x > 1360 and absf(player.position.y - 620) < 2, "中岛真实跳到右岛，完整断阶路线可达"): return
	var camera: Camera2D = player.get_node("Camera2D")
	if not check(camera.limit_right == 1672 and camera.limit_bottom == 941 and camera.get_screen_center_position().x > 800, "世界相机随角色穿过断桥且限定原图边界"): return
	player.reset_motion_at(Vector2(950, 1000))
	await frames(40)
	if not check(player.health == 0 and player.state == player.State.DEAD, "坠落裂隙进入既有死亡状态"): return
	print("PAINTED_MAP_CHECKS_PASSED=", checks)
	quit()
