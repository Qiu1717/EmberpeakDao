extends "res://scripts/art/actor_frame_visual.gd"
var gait_distance := 0.0
var previous_position := Vector2.ZERO
var state_time := 0.0
var previous_state := -1
@onready var player: CharacterBody2D = get_parent()

func _ready() -> void:
	configure("res://assets/animations/shen_jin/", 56.0, player.get_node("Artwork"))
	previous_position = player.global_position
	sync_pose()

func _physics_process(delta: float) -> void:
	gait_distance += absf(player.global_position.x - previous_position.x)
	previous_position = player.global_position
	state_time += delta
	sync_pose()

func sync_pose() -> void:
	if previous_state != player.state:
		state_time = 0
		previous_state = player.state
	var name := "idle"
	var time: float = player.action_time
	var duration := 0.0
	match player.state:
		player.State.MOVE:
			name = "run"
			time = fposmod(gait_distance / float(manifest.stride_distance), 1.0) * clip_duration(name)
		player.State.JUMP:
			name = "jump"
		player.State.ATTACK:
			if time < player.attack_windup():
				name = "attack_windup"
				duration = player.attack_windup()
			elif time < player.attack_windup() + player.attack_active():
				name = "attack_" + str(player.combo + 1)
				time -= player.attack_windup()
				duration = player.attack_active()
			else:
				name = "attack_recover"
				time -= player.attack_windup() + player.attack_active()
				duration = player.attack_duration() - player.attack_windup() - player.attack_active()
		player.State.DODGE:
			name = "dodge"
			duration = player.stats.dodge_duration
		player.State.HURT:
			name = "hurt"
			duration = player.stats.hit_stun
		player.State.DEAD:
			name = "death"
			time = state_time
		_:
			time = fposmod(state_time, clip_duration(name))
	show_clip(name, time, player.facing, duration)
