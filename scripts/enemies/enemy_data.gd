extends Resource
@export var enemy_id := ""
@export var display_name := ""
@export var max_health := 90
@export var move_speed := 140.0
@export_enum("melee", "agile", "ghost", "ranged", "elite", "boss") var behavior := "melee"
@export var concept_texture: Texture2D
@export var attacks: Array[Resource] = []
@export_group("阶段3测试参数，非最终平衡")
@export var body_size := Vector2(32, 56)
@export var detection_range := 650.0
@export var leash_range := 1000.0
@export var patrol_range := 100.0
@export var gravity := 1500.0
@export var hit_stun := 0.20
@export var armor_points := 0.0
@export var armor_reduction := 0.0
@export var armor_break_stun := 0.65
@export var phase_health := 0.0
@export var intro_duration := 0.0
@export var phase_duration := 1.0
@export var death_duration := 0.60
