extends "res://scripts/art/actor_frame_visual.gd"
var gait_distance := 0.0
var previous_position := Vector2.ZERO
@onready var enemy: CharacterBody2D = get_parent()

func _ready() -> void:
	configure("res://assets/animations/" + enemy.data.enemy_id + "/", enemy.data.body_size.y)
	previous_position = enemy.global_position
	sync_pose()

func _physics_process(_delta: float) -> void:
	gait_distance += absf(enemy.global_position.x - previous_position.x)
	previous_position = enemy.global_position
	sync_pose()

func sync_pose() -> void:
	var name := "idle"
	var time: float = enemy.clock
	var duration := 0.0
	match enemy.state:
		enemy.State.DEAD:
			name = "death"
			duration = enemy.data.death_duration
		enemy.State.HURT:
			name = "hurt"
			duration = enemy.hurt_duration
		enemy.State.PHASE:
			name = "phase" if enemy.data.behavior == "boss" else "hurt"
			duration = enemy.data.phase_duration
		enemy.State.TELEGRAPH, enemy.State.ATTACK, enemy.State.RECOVERY:
			var suffix := "telegraph"
			duration = enemy.attack.windup
			if enemy.state == enemy.State.ATTACK:
				suffix = "attack"
				duration = enemy.attack.active_time
			elif enemy.state == enemy.State.RECOVERY:
				suffix = "recovery"
				duration = enemy.attack.recovery
			if enemy.data.behavior == "boss":
				var mode: String = enemy.attack.attack_id
				if mode == "double_slash":
					mode = "slash"
					if enemy.state == enemy.State.ATTACK:
						duration /= enemy.attack.burst
						time = fposmod(time, duration)
				if mode == "leap" and enemy.state == enemy.State.RECOVERY:
					mode = "slam"
				name = mode + "_" + suffix
			else:
				var alternate: bool = enemy.attack.kind in ["lunge", "slam"]
				name = ("alt_" if alternate else "") + suffix
		_:
			if absf(enemy.velocity.x) > 1:
				name = "run"
				time = fposmod(gait_distance / float(manifest.stride_distance), 1.0) * clip_duration(name)
			else:
				time = fposmod(time, clip_duration(name))
	show_clip(name, time, enemy.facing, duration)
