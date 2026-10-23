extends SceneTree
var checks := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("FAIL: " + message)
		quit(1)
		return false
	checks += 1
	print("PASS: " + message)
	return true
func run() -> void:
	var path := "res://assets/enemies/shan_xiao/validation/pounce_v1/manifest.json"
	if not check(FileAccess.file_exists(path), "动作清单真实存在"):
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var total := 0.0
	var unique: Dictionary = {}
	for frame in manifest.frames:
		var image := Image.load_from_file(path.get_base_dir().path_join(frame.file))
		if not check(not image.is_empty() and image.get_size() == Vector2i(1254, 1254) and image.get_format() == Image.FORMAT_RGBA8, "透明单帧存在且画布一致：" + frame.pose):
			return
		total += frame.duration
		unique[frame.file] = true
	if not check(unique.size() == 7 and manifest.frames.size() == 8 and is_equal_approx(total, 1.45), "7个真实姿势、8帧槽和1.45秒完整时长"):
		return
	if not check(ResourceLoader.exists("res://scenes/art/shan_xiao_pounce_preview.tscn"), "独立美术预览场景存在"):
		return
	change_scene_to_file("res://scenes/art/shan_xiao_pounce_preview.tscn")
	await process_frame
	await process_frame
	var preview: Node = current_scene
	if not check(preview.sprite_frames.get_frame_count("pounce") == 8, "真实PNG已装入SpriteFrames"):
		return
	preview.seek(0.55)
	if not check(preview.large_sprite.frame == 3 and preview.small_sprite.frame == 3, "前摇后进入腾空扑击真实帧"):
		return
	preview.seek(0.81)
	if not check(preview.large_sprite.frame == 6, "攻击窗口后进入收招真实帧"):
		return
	preview.seek(0)
	await create_timer(0.25).timeout
	if not check(preview.large_sprite.frame > 0, "正常播放实际切换姿势"):
		return
	preview.playing = false
	var frozen: float = preview.elapsed
	await create_timer(0.15).timeout
	if not check(preview.elapsed == frozen, "暂停保持当前动作时间"):
		return
	preview.step_frame(1)
	if not check(preview.large_sprite.frame > 0 and not preview.playing, "逐帧操作保持暂停并切换画面"):
		return
	preview.seek(0.55)
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://builds/art_sample")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/art_sample/preview.png")
	print("ART_CHECKS_PASSED=", checks)
	quit()
