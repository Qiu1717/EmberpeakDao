extends Node2D
## 单姿势静态美术，读取真实状态；不驱动AI、碰撞或伤害。
var sprite := Sprite2D.new()
var pivot := Vector2.ZERO
var native_facing := -1
@onready var enemy: CharacterBody2D = get_parent()

func _ready() -> void:
	var poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies/static_v1/manifest.json"))
	var pose: Dictionary = poses[enemy.data.enemy_id]
	native_facing = pose.native_facing
	sprite.texture = load("res://assets/enemies/static_v1/" + pose.file)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var ratio: float = sprite.texture.get_width() / float(pose.canvas[0])
	pivot = Vector2(pose.pivot[0], pose.pivot[1]) * ratio
	sprite.offset = -pivot
	sprite.scale = Vector2.ONE * enemy.data.body_size.y / (pose.visible_height * ratio)
	add_child(sprite)
	sync_pose()

func _physics_process(_delta: float) -> void:
	sync_pose()

func sync_pose() -> void:
	scale.x = enemy.facing * native_facing
	sprite.modulate = Color("9e302a") if enemy.state == enemy.State.HURT else Color.WHITE
