extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal state_changed(state: int)
signal died
const Damage := preload("res://scripts/combat/damage.gd")
enum State { IDLE, MOVE, JUMP, ATTACK, DODGE, HURT, DEAD }
@export var stats: Resource = preload("res://resources/player/training_stats.tres")
var health: int
var state: State = State.IDLE
var facing := 1
var action_time := 0.0
var dodge_remaining := 0.0
var combo_remaining := 0.0
var combo := -1
var jump_remaining := 0.0
var coyote_remaining := 0.0
var hit_targets: Dictionary = {}
var rng := RandomNumberGenerator.new()
var attack_requested := false
var dodge_requested := false

func _ready() -> void:
	stats = stats.duplicate(true)
	health = stats.max_health
	rng.seed = 20261023
	$Artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	health_changed.emit(health, stats.max_health)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("attack"):
		attack_requested = true
	if event.is_action_pressed("dodge"):
		dodge_requested = true

func _physics_process(delta: float) -> void:
	var attack_input := attack_requested
	var dodge_input := dodge_requested
	attack_requested = false
	dodge_requested = false
	dodge_remaining = maxf(0, dodge_remaining - delta)
	combo_remaining = maxf(0, combo_remaining - delta)
	coyote_remaining = stats.coyote_time if is_on_floor() else maxf(0, coyote_remaining - delta)
	if state == State.DEAD:
		velocity.x = 0
		velocity.y += stats.gravity * delta
		move_and_slide()
		return
	if state == State.DODGE:
		var step := minf(delta, stats.dodge_duration - action_time)
		velocity = Vector2(facing * stats.dodge_distance / stats.dodge_duration * step / delta, 0)
		move_and_slide()
		action_time += step
		if action_time >= stats.dodge_duration - 0.00001:
			velocity = Vector2.ZERO
			_set_state(State.IDLE if is_on_floor() else State.JUMP)
		queue_redraw()
		return
	velocity.y += stats.gravity * delta
	if state == State.HURT:
		action_time += delta
		velocity.x = move_toward(velocity.x, 0, stats.deceleration * delta)
		move_and_slide()
		if action_time >= stats.hit_stun:
			_set_state(State.IDLE if is_on_floor() else State.JUMP)
		return
	if dodge_input and try_dodge():
		return
	if state == State.ATTACK:
		action_time += delta
		velocity.x = move_toward(velocity.x, 0, stats.deceleration * delta)
		if action_time >= stats.attack_windup and action_time < stats.attack_windup + stats.attack_active:
			_query_attack()
		move_and_slide()
		if action_time >= stats.attack_duration:
			_set_state(State.IDLE if is_on_floor() else State.JUMP)
		queue_redraw()
		return
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		facing = 1 if direction > 0 else -1
	var accel: float = stats.acceleration if is_on_floor() else stats.air_acceleration
	velocity.x = move_toward(velocity.x, direction * stats.move_speed, (stats.deceleration if direction == 0 else accel) * delta)
	jump_remaining = stats.jump_buffer if Input.is_action_just_pressed("jump") else maxf(0, jump_remaining - delta)
	if jump_remaining > 0 and coyote_remaining > 0:
		velocity.y = stats.jump_velocity
		jump_remaining = 0
		coyote_remaining = 0
	move_and_slide()
	_set_state(State.JUMP if not is_on_floor() else (State.MOVE if absf(velocity.x) > 1 else State.IDLE))
	if attack_input:
		try_attack()
	queue_redraw()

func _set_state(value: State) -> void:
	if state != value:
		state = value
		state_changed.emit(state)
		queue_redraw()

func try_dodge() -> bool:
	if state in [State.DEAD, State.HURT, State.DODGE] or dodge_remaining > 0:
		return false
	action_time = 0
	dodge_remaining = stats.dodge_cooldown
	hit_targets.clear()
	_set_state(State.DODGE)
	return true

func is_invulnerable() -> bool:
	return state == State.DODGE and action_time < stats.dodge_iframes

func try_attack() -> bool:
	if state in [State.ATTACK, State.DODGE, State.HURT, State.DEAD]:
		return false
	combo = (combo + 1) % stats.sword_damage.size() if combo_remaining > 0 else 0
	combo_remaining = stats.combo_window
	action_time = 0
	hit_targets.clear()
	_set_state(State.ATTACK)
	return true

func _query_attack() -> void:
	var shape := RectangleShape2D.new()
	shape.size = stats.attack_size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, global_position + Vector2(facing * stats.attack_offset.x, stats.attack_offset.y))
	query.collision_mask = 4
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var target: Object = hit.collider
		if hit_targets.has(target.get_instance_id()) or not target.has_method("receive_hit"):
			continue
		hit_targets[target.get_instance_id()] = true
		var critical: float = stats.critical_multiplier if rng.randf() < stats.critical_chance else 1.0
		var raw: float = stats.sword_damage[combo] * stats.realm_multiplier * critical
		target.receive_hit(raw, Vector2(facing * stats.knockback.x, stats.knockback.y))

func receive_hit(amount: float, impulse: Vector2) -> bool:
	if health <= 0 or is_invulnerable() or amount <= 0:
		return false
	health = maxi(0, health - Damage.resolve(amount, stats.defense))
	velocity = impulse
	action_time = 0
	hit_targets.clear()
	_set_state(State.DEAD if health == 0 else State.HURT)
	health_changed.emit(health, stats.max_health)
	if health == 0:
		died.emit()
	return true

func _process(_delta: float) -> void:
	# shortcut: 单张侧视工作图，仅翻转和状态着色；后续完整动作另行制作。
	var color := Color.WHITE
	if state == State.DODGE:
		color = Color("83dce8")
	elif state == State.HURT:
		color = Color("9e302a")
	elif state == State.DEAD:
		color = Color("596a6f")
	$Artwork.modulate = color
	$Artwork.scale.x = -facing * absf($Artwork.scale.y)

func _draw() -> void:
	if state == State.ATTACK:
		var active: bool = action_time >= stats.attack_windup and action_time < stats.attack_windup + stats.attack_active
		if active:
			draw_rect(Rect2(Vector2(facing * stats.attack_offset.x, stats.attack_offset.y) - stats.attack_size / 2, stats.attack_size), Color(0.51, 0.86, 0.91, 0.25))
			draw_line(Vector2(0, -30), Vector2(facing * 105, -30), Color("83dce8"), 4)

func reset_motion_at(spawn: Vector2) -> void:
	# 换房仅清动作；生命与角色配置保持本次路线的实际值。
	global_position = spawn
	velocity = Vector2.ZERO
	attack_requested = false
	dodge_requested = false
	action_time = 0
	combo = -1
	combo_remaining = 0
	jump_remaining = 0
	coyote_remaining = 0
	hit_targets.clear()
	_set_state(State.IDLE if health > 0 else State.DEAD)
	$Camera2D.reset_smoothing()
