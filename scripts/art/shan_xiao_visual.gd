extends Node2D
## 表现读取AI时钟；不驱动移动、伤害、无敌或死亡结算。
const Directory := "res://assets/enemies/shan_xiao/playable_v1/"
const Enemy := preload("res://scripts/enemies/enemy.gd")
var manifest: Dictionary
var sprite := AnimatedSprite2D.new()
var animation_name := ""
var show_body_bounds := false
var gait_distance := 0.0
var previous_position := Vector2.ZERO
@onready var enemy: Enemy = get_parent()

func _ready() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(Directory + "manifest.json"))
	var frames := SpriteFrames.new()
	for id: String in manifest.clips:
		frames.add_animation(id)
		frames.set_animation_speed(id, 1)
		for entry: Dictionary in manifest.clips[id]:
			var pose: Dictionary = manifest.poses[entry.pose]
			frames.add_frame(id, load(Directory + pose.file), entry.duration)
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	previous_position = enemy.global_position
	sync_pose()

func _physics_process(_delta: float) -> void:
	gait_distance += absf(enemy.global_position.x - previous_position.x)
	previous_position = enemy.global_position
	sync_pose()

func sync_pose() -> void:
	var time: float = enemy.clock
	match enemy.state:
		Enemy.State.DEAD:
			animation_name = "death"
			time *= 0.60 / enemy.data.death_duration
		Enemy.State.HURT:
			animation_name = "hurt"
			time *= 0.20 / enemy.hurt_duration
		Enemy.State.TELEGRAPH:
			animation_name = "telegraph"
			time *= 0.50 / enemy.attack.windup
		Enemy.State.ATTACK:
			animation_name = "airborne" if not enemy.is_on_floor() else "recovery"
			time *= 0.30 / enemy.attack.active_time
		Enemy.State.RECOVERY:
			animation_name = "recovery" if enemy.is_on_floor() else "airborne"
			time = time * 0.65 / enemy.attack.recovery if enemy.is_on_floor() else 0.299
		_:
			animation_name = "run" if absf(enemy.velocity.x) > 1 and enemy.is_on_floor() else "idle"
			if animation_name == "run":
				time = fposmod(gait_distance / manifest.stride_distance, 1.0) * 0.56
			else:
				time = fposmod(time, 1.6)
	var clip: Array = manifest.clips[animation_name]
	var index: int = clip.size() - 1
	var boundary := 0.0
	for slot in clip.size():
		boundary += clip[slot].duration
		if time < boundary:
			index = slot
			break
	sprite.animation = animation_name
	sprite.frame = index
	var pose: Dictionary = manifest.poses[clip[index].pose]
	# Godot导入缩图不改源PNG；按实际纹理尺寸换算源画布的枢轴。
	var texture := sprite.sprite_frames.get_frame_texture(animation_name, index)
	var ratio: float = texture.get_width() / float(pose.canvas[0])
	sprite.offset = -Vector2(pose.pivot[0], pose.pivot[1]) * ratio
	sprite.scale = Vector2.ONE * manifest.world_scale / ratio
	scale.x = -enemy.facing
	queue_redraw()

func _draw() -> void:
	if show_body_bounds:
		draw_rect(Rect2(Vector2(-16, -56), Vector2(32, 56)), Color("83dce8"), false, 1)
