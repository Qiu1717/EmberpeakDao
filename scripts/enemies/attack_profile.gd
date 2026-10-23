extends Resource
## 未由主方案指定的时间与范围都是阶段3测试参数。
@export var attack_id := "strike"
@export var display_name := "挥击"
@export_enum("melee", "lunge", "shot", "slam", "leap", "wave") var kind := "melee"
@export var damage := 12.0
@export var reach := 90.0
@export var windup := 0.55
@export var active_time := 0.18
@export var recovery := 0.65
@export var cooldown := 0.35
@export var hit_size := Vector2(100, 64)
@export var move_speed := 0.0
@export var leap_velocity := -650.0
@export var projectile_speed := 480.0
@export var burst := 1
@export var minimum_phase := 1
