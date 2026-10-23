extends Node2D
## 只切换表现帧；所有时钟、攻击窗口与朝向由实际角色提供。
var manifest: Dictionary
var sprite: Sprite2D
var pivot := Vector2.ZERO
var native_facing := 1
var animation_name := ""
var pose_name := ""
var frame_index := 0
var textures: Dictionary = {}
var import_ratio := Vector2.ONE
var world_scale := 1.0

func configure(directory: String, height: float, artwork: Sprite2D = null) -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(directory + "manifest.json"))
	var sheet: Texture2D = load(directory + manifest.texture)
	var canvas: Array = manifest.get("source_canvas", manifest.get("canvas"))
	import_ratio = sheet.get_size() / Vector2(canvas[0], canvas[1])
	world_scale = height / float(manifest.reference_height)
	native_facing = int(manifest.native_facing)
	for key: String in manifest.poses:
		var region: Array = manifest.poses[key].region
		var texture := AtlasTexture.new()
		texture.atlas = sheet
		texture.region = Rect2(Vector2(region[0], region[1]) * import_ratio, Vector2(region[2], region[3]) * import_ratio)
		texture.filter_clip = true
		textures[key] = texture
	sprite = artwork if artwork != null else Sprite2D.new()
	if artwork == null:
		add_child(sprite)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func clip_duration(name: String) -> float:
	var duration := 0.0
	for entry: Dictionary in manifest.clips[name]:
		duration += float(entry.duration)
	return duration

func show_clip(name: String, time: float, facing: int, state_duration: float = 0.0, looping: bool = false) -> void:
	animation_name = name
	var duration := clip_duration(name)
	if state_duration > 0:
		time *= duration / state_duration
	if looping:
		time = fposmod(time, duration)
	var clip: Array = manifest.clips[name]
	frame_index = clip.size() - 1
	var boundary := 0.0
	for index in clip.size():
		boundary += float(clip[index].duration)
		if time < boundary:
			frame_index = index
			break
	pose_name = clip[frame_index].pose
	var pose: Dictionary = manifest.poses[pose_name]
	native_facing = int(pose.get("native_facing", manifest.native_facing))
	pivot = Vector2(pose.pivot[0], pose.pivot[1]) * import_ratio
	sprite.texture = textures[pose_name]
	sprite.offset = -pivot
	# 统一源轮廓比例；只补偿导入缩图，绝不把每帧拉伸到同一高度。
	sprite.scale = Vector2(facing * native_facing * world_scale / import_ratio.x, world_scale / import_ratio.y)
