extends Control
## 仅美术验证；不接入敌人AI、不修改伤害或碰撞。
const Ui := preload("res://scripts/ui/ui_style.gd")
const Directory := "res://assets/enemies/shan_xiao/validation/pounce_v1/"
const Stats := preload("res://resources/enemies/shan_xiao.tres")
var manifest: Dictionary
var sprite_frames := SpriteFrames.new()
var large_sprite := AnimatedSprite2D.new()
var small_sprite := AnimatedSprite2D.new()
var elapsed := 0.0
var playing := true
var speed := 1.0
var motion_enabled := true
var status: Label
var play_button: Button
var native_scale := 56.0 / 1125.0

func _ready() -> void:
	theme = Ui.theme()
	manifest = JSON.parse_string(FileAccess.get_file_as_string(Directory + "manifest.json"))
	sprite_frames.add_animation("pounce")
	sprite_frames.set_animation_speed("pounce", 1.0)
	sprite_frames.set_animation_loop_mode("pounce", SpriteFrames.LOOP_NONE)
	for entry in manifest.frames:
		var image := Image.load_from_file(Directory + entry.file)
		if image.is_empty():
			push_error("动作帧读取失败：" + entry.file)
			return
		sprite_frames.add_frame("pounce", ImageTexture.create_from_image(image), entry.duration)
	for sprite in [large_sprite, small_sprite]:
		sprite.sprite_frames = sprite_frames
		sprite.animation = "pounce"
		sprite.centered = false
		sprite.offset = -Vector2(manifest.pivot[0], manifest.pivot[1])
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
	large_sprite.scale = Vector2.ONE * 0.18
	small_sprite.scale = Vector2.ONE * native_scale
	_label("山魈幼体 · 扑击动作样片", Vector2(40, 24), 32)
	_label("7个不同绘制姿势／8个播放帧槽 · 未作正式美术验收 · 不替换关卡角色", Vector2(40, 72), 17)
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(40, 112)
	buttons.add_theme_constant_override("separation", 12)
	add_child(buttons)
	Ui.button(buttons, "上一帧", "Previous", func(): step_frame(-1), self)
	play_button = Ui.button(buttons, "暂停", "Play", toggle_playing, self)
	Ui.button(buttons, "下一帧", "Next", func(): step_frame(1), self)
	Ui.button(buttons, "从头播放", "Restart", func(): elapsed = 0; playing = true, self)
	Ui.button(buttons, "切换半速／正常", "Speed", func(): speed = 0.5 if speed == 1 else 1.0, self)
	var motion := CheckBox.new()
	motion.text = "预览扑击位移"
	motion.button_pressed = true
	motion.toggled.connect(func(value: bool): motion_enabled = value)
	buttons.add_child(motion)
	for button in buttons.get_children():
		button.focus_mode = Control.FOCUS_NONE
	status = _label("", Vector2(40, 170), 18)
	_label("放大检查（相同画布与枢轴）", Vector2(40, 225), 17)
	_label("当前56像素高度对照", Vector2(980, 225), 17)
	_label("仅用于比较可读性，非最终角色尺寸", Vector2(950, 510), 14)
	_label("前摇0.50秒 → 有效0.30秒 → 收招0.65秒；循环之间复位。Space暂停，←/→逐帧，Esc退出。", Vector2(40, 690), 15)
	_update_pose()

func _label(text: String, point: Vector2, font_size: int) -> Label:
	var label := Ui.label(self, text, font_size)
	label.position = point
	return label

func _process(delta: float) -> void:
	if playing:
		elapsed = fmod(elapsed + delta * speed, manifest.duration + 0.7)
	_update_pose()

func _update_pose() -> void:
	var index: int = manifest.frames.size() - 1
	var boundary := 0.0
	for frame in manifest.frames.size():
		boundary += manifest.frames[frame].duration
		if elapsed < boundary:
			index = frame
			break
	large_sprite.frame = index
	small_sprite.frame = index
	var time := maxf(0, elapsed - manifest.windup)
	var profile: Resource = Stats.attacks[0]
	var displacement := Vector2(-profile.move_speed * minf(time, profile.active_time), minf(0, profile.leap_velocity * time + Stats.gravity * time * time / 2)) if motion_enabled else Vector2.ZERO
	large_sprite.position = Vector2(770, 490) + displacement * (0.18 / native_scale)
	small_sprite.position = Vector2(1190, 490) + displacement
	status.text = "%d / 8　%s　%s　%.2f / 1.45秒　速度×%.1f" % [index + 1, manifest.frames[index].phase, manifest.frames[index].pose, minf(elapsed, manifest.duration), speed]
	play_button.text = "暂停" if playing else "播放"
	queue_redraw()

func toggle_playing() -> void:
	playing = not playing

func seek(seconds: float) -> void:
	elapsed = clampf(seconds, 0, manifest.duration - 0.00001)
	_update_pose()

func step_frame(direction: int) -> void:
	playing = false
	var next := posmod(large_sprite.frame + direction, manifest.frames.size())
	var time := 0.0
	for frame in next:
		time += manifest.frames[frame].duration
	seek(time + 0.00001)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: toggle_playing()
			KEY_LEFT: step_frame(-1)
			KEY_RIGHT: step_frame(1)
			KEY_ESCAPE: get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("07141b"))
	draw_line(Vector2(40, 490), Vector2(900, 490), Color("315461"), 2)
	draw_line(Vector2(950, 490), Vector2(1240, 490), Color("315461"), 2)
	if manifest.is_empty() or sprite_frames.get_frame_count("pounce") == 0:
		return
	for index in manifest.frames.size():
		var cell := Rect2(40 + index * 150, 550, 142, 130)
		draw_rect(cell, Color("153642") if index == large_sprite.frame else Color("0d2029"))
		draw_texture_rect(sprite_frames.get_frame_texture("pounce", index), Rect2(cell.position, Vector2(125, 125)), false)
		draw_string(theme.default_font, cell.position + Vector2(5, 125), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
