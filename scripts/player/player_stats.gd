extends Resource
## 已定基准与未定调试参数分开列出，均由训练资源提供。
@export var max_health: int = 100
@export var move_speed: float = 280.0
@export var defense: float = 0.0
@export var realm_multiplier: float = 1.0
@export var critical_chance: float = 0.05
@export var critical_multiplier: float = 1.5
@export var dodge_distance: float = 150.0
@export var dodge_iframes: float = 0.20
@export var dodge_cooldown: float = 0.70
@export var hit_stun: float = 0.20
@export var sword_damage: PackedFloat32Array = [14.0, 18.0, 24.0]
@export_group("训练调试参数，非最终平衡")
@export var gravity: float = 1500.0
@export var jump_velocity: float = -600.0
@export var acceleration: float = 2200.0
@export var deceleration: float = 2600.0
@export var air_acceleration: float = 1400.0
@export var jump_buffer: float = 0.10
@export var coyote_time: float = 0.10
@export var dodge_duration: float = 0.20
@export var attack_windup: float = 0.10
@export var attack_active: float = 0.10
@export var attack_duration: float = 0.42
@export var combo_window: float = 0.70
@export var attack_size: Vector2 = Vector2(100, 58)
@export var attack_offset: Vector2 = Vector2(60, -30)
@export var knockback: Vector2 = Vector2(180, -100)
