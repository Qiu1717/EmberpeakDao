extends SceneTree
var checks := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, text: String) -> bool:
	if not ok:
		push_error("FAIL: " + text)
		quit(1)
		return false
	checks += 1
	print("PASS: " + text)
	return true
func frames(count: int = 3) -> void:
	for index in count:
		await physics_frame
	# process_frame 先于节点 _process 发出，等待下一轮才能读取已更新的表现。
	await process_frame
	await process_frame
func capture(id: String) -> void:
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://builds/player_art")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/player_art/" + id + ".png")
func run() -> void:
	var initial: Node = load("res://scenes/player/player.tscn").instantiate()
	var present := initial.has_node("Artwork")
	initial.free()
	if not check(present, "主角场景接入真实Artwork精灵"):
		return
	var app: Node = root.get_node("App")
	for entry in ["training", "route", "art_room"]:
		match entry:
			"training": await app.start_training()
			"route": await app.start_new_game()
			"art_room": await app.start_art_room()
		await frames(5)
		var player: Node = current_scene.player
		var art: Sprite2D = player.get_node("Artwork")
		if not check(art.texture is AtlasTexture and art.is_visible_in_tree(), entry + " 使用实际导入的动作图集切片"):
			return
		if not check(player.health == 100 and player.get_node("CollisionShape2D").shape.size == Vector2(24, 56), entry + " 保留100生命和24×56碰撞"):
			return
		var visual: Node = player.get_node("ArtworkController")
		if not check(absf(visual.world_scale * float(visual.manifest.reference_height) - 56) < 0.01, entry + " 统一中立轮廓比例为56世界像素"):
			return
		for direction in [-1, 1]:
			player.facing = direction
			await frames()
			var pose: Dictionary = visual.manifest.poses[visual.pose_name]
			var source_pivot := Vector2(pose.pivot[0], pose.pivot[1])
			var foot := art.to_global(art.offset + source_pivot * visual.import_ratio)
			if not check(foot.distance_to(player.global_position) < 0.01 and signf(art.scale.x) == direction * visual.native_facing, entry + " 翻转保留脚底锚点：" + str(direction)):
				return
		await capture(entry)
	var player: Node = current_scene.player
	var art: Sprite2D = player.get_node("Artwork")
	player.receive_hit(1, Vector2.ZERO)
	await frames(1)
	var visual: Node = player.get_node("ArtworkController")
	if not check(player.state == player.State.HURT and visual.animation_name == "hurt", "真实受击状态切换受击动作帧"):
		return
	app.set_paused(true)
	var texture: Texture2D = art.texture
	var elapsed: float = visual.state_time
	await create_timer(0.1).timeout
	if not check(art.texture == texture and visual.state_time == elapsed, "暂停冻结当前动作帧与表现时钟"):
		return
	app.set_paused(false)
	player.receive_hit(1000, Vector2.ZERO)
	await frames(1)
	texture = art.texture
	await create_timer(0.4).timeout
	await frames(1)
	if not check(player.health == 0 and visual.animation_name == "death" and art.texture != texture, "死亡随实际时间播放两个独立倒下姿势"):
		return
	await app.start_art_room()
	await frames()
	if not check(current_scene.player.health == 100 and current_scene.player.get_node("ArtworkController").animation_name == "idle", "重开恢复生命与中立动作"):
		return
	print("PLAYER_ART_CHECKS_PASSED=", checks)
	quit()
