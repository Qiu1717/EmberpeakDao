extends SceneTree
## 有界实机录制：使用实际移动/跳跃/攻击输入，不修改资源数值。
func _initialize() -> void:
	run.call_deferred()
func frames(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame
	await process_frame
func action(id: String) -> void:
	var input := InputEventAction.new()
	input.action = id
	input.pressed = true
	Input.parse_input_event(input)
	await frames(2)
	input.pressed = false
	Input.parse_input_event(input)
func capture(id: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://builds/animated_map/" + id + ".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds/animated_map")
	await root.get_node("App").start_new_game()
	await frames(15)
	var player: Node = current_scene.player
	capture("entry_idle")
	Input.action_press("move_right")
	await frames(18)
	capture("entry_run_a")
	await frames(8)
	capture("entry_run_b")
	await action("jump")
	await frames(10)
	capture("entry_jump")
	await frames(65)
	Input.action_release("move_right")
	await frames(10)
	for combo in 3:
		await action("attack")
		await frames(6)
		capture("entry_attack_%d" % (combo + 1))
		await frames(20)
	await action("dodge")
	await frames(3)
	capture("entry_dodge")
	await frames(20)
	Input.action_press("move_right")
	await frames(110)
	Input.action_release("move_right")
	await frames(10)
	capture("entry_camera_right")
	player.receive_hit(1, Vector2.ZERO)
	await frames(2)
	capture("entry_hurt")
	await frames(15)
	player.receive_hit(1000, Vector2.ZERO)
	await frames(25)
	capture("entry_death")
	await preview_enemies()
	print("PLAYABLE_MAP_PREVIEW_CAPTURED")
	quit()

func preview_enemies() -> void:
	# 截图观察夹具使用高生命主角，避免等待AI动作时死亡；不修改生产资源。
	var route: Node = current_scene.get_node("World/SwordRoute")
	var actors := {"corpse": 1, "ghost": 2, "crossbow": 2, "armored_xiao": 3, "mountain_general": 5}
	for id: String in actors:
		route.player.health = 10000
		route.enter_room(actors[id])
		await frames(3)
		var room: Node = route.room
		var selected: Node
		for enemy in room.enemies:
			if enemy.data.enemy_id == id:
				selected = enemy
			else:
				enemy.set_physics_process(false)
				enemy.hide()
		var player: Node = route.player
		player.set_physics_process(false)
		player.reset_motion_at(Vector2(530, room.map.floor_at(530)))
		selected.position = Vector2(760, room.map.floor_at(760))
		selected.home = selected.position
		selected.velocity = Vector2.ZERO
		selected.activate(player)
		await frames(12)
		capture(id + "_idle")
		var seen: Dictionary = {}
		for tick in 850:
			await frames(1)
			if selected.state in [selected.State.TELEGRAPH, selected.State.ATTACK, selected.State.RECOVERY] and not seen.has(selected.state):
				seen[selected.state] = true
				capture(id + "_" + selected.get_node("Visual").animation_name)
			if seen.size() == 3:
				break
		print("PREVIEW_AI_PHASES=", id, ":", seen.size())
		selected.receive_hit(1, Vector2.ZERO)
		await frames(2)
		capture(id + "_hurt")
		await frames(18)
		selected.receive_hit(100000, Vector2.ZERO)
		await frames(14)
		capture(id + "_death")
		route.player.set_physics_process(true)
