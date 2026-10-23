extends SceneTree
var checks := 0
const SourcePivot := Vector2(590, 1244)
const SourceHeight := 1229.0
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
		if not check(art.texture != null and art.texture.get_width() == 512 and art.is_visible_in_tree(), entry + " 使用实际导入的侧视纹理"):
			return
		if not check(player.health == 100 and player.get_node("CollisionShape2D").shape.size == Vector2(24, 56), entry + " 保留100生命和24×56碰撞"):
			return
		if not check(absf(art.scale.y * 512 * SourceHeight / 1254 - 56) < 0.01, entry + " 可见中立轮廓高度为56世界像素"):
			return
		for direction in [-1, 1]:
			player.facing = direction
			await frames()
			var foot := art.to_global(art.offset + SourcePivot * (512.0 / 1254))
			if not check(foot.distance_to(player.global_position) < 0.01 and signf(art.scale.x) == -direction, entry + " 翻转保留脚底锚点：" + str(direction)):
				return
		await capture(entry)
	var player: Node = current_scene.player
	var art: Sprite2D = player.get_node("Artwork")
	player.receive_hit(1, Vector2.ZERO)
	await frames(1)
	if not check(player.state == player.State.HURT and art.modulate == Color("9e302a"), "静态角色随真实受击状态变色提示"):
		return
	app.set_paused(true)
	var color := art.modulate
	await create_timer(0.1).timeout
	if not check(art.modulate == color, "暂停保持当前静态表现"):
		return
	app.set_paused(false)
	player.receive_hit(1000, Vector2.ZERO)
	await frames(1)
	if not check(player.health == 0 and art.modulate == Color("596a6f"), "死亡只做明确状态着色，不冒充死亡动画"):
		return
	await app.start_art_room()
	await frames()
	if not check(current_scene.player.health == 100 and current_scene.player.get_node("Artwork").modulate == Color.WHITE, "重开恢复生命与原始素材颜色"):
		return
	print("PLAYER_ART_CHECKS_PASSED=", checks)
	quit()
