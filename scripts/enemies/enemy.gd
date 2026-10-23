extends CharacterBody2D
signal state_changed(state: int)
signal died(source_id: String)
signal reward_requested(payload: Dictionary)
signal phase_changed(phase: int)
signal attack_started(attack_id: String)

const Damage := preload("res://scripts/combat/damage.gd")
const Projectile := preload("res://scripts/enemies/projectile.gd")
enum State { DORMANT, INTRO, IDLE, PATROL, DETECT, APPROACH, TELEGRAPH, ATTACK, RECOVERY, RETURN, HURT, PHASE, DEAD }
@export var data: Resource
@export var show_placeholder_body := true
var source_id := ""
var health := 0
var armor := 0.0
var phase := 1
var state: State = State.DORMANT
var target: CharacterBody2D
var home := Vector2.ZERO
var facing := -1
var clock := 0.0
var cooldown := 0.0
var attack_cursor := 0
var attack: Resource
var aimed_position := Vector2.ZERO
var launch_velocity := Vector2.ZERO
var hit_targets: Dictionary = {}
var last_burst := -1
var hurt_duration := 0.20
var impact_done := false
var dropped_platforms: Array[PhysicsBody2D] = []

func _ready() -> void:
	data = data.duplicate(true)
	health = data.max_health
	armor = data.armor_points
	home = global_position
	if source_id.is_empty():
		source_id = str(get_instance_id())
	var shape := RectangleShape2D.new()
	shape.size = data.body_size
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position.y = -data.body_size.y / 2
	var label := Label.new()
	label.text = data.display_name
	label.position = Vector2(-85, -data.body_size.y - 38)
	label.size.x = 170
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)
	var visual := Node2D.new()
	visual.name = "Visual"
	visual.set_script(load("res://scripts/art/shan_xiao_visual.gd" if data.enemy_id == "shan_xiao" else "res://scripts/art/enemy_animation_visual.gd"))
	add_child(visual)
	show_placeholder_body = false
	queue_redraw()

func activate(player: CharacterBody2D) -> void:
	target = player
	_set_state(State.INTRO if data.intro_duration > 0 else State.IDLE)

func _set_state(value: State) -> void:
	state = value
	clock = 0
	state_changed.emit(state)
	queue_redraw()

func _has_sight() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -35), target.global_position + Vector2(0, -28), 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _physics_process(delta: float) -> void:
	clock += delta
	cooldown = maxf(0, cooldown - delta)
	velocity.y += data.gravity * delta
	if state == State.DEAD:
		velocity.x = 0
		modulate.a = maxf(0, 1 - clock / data.death_duration)
		move_and_slide()
		if clock >= data.death_duration:
			queue_free()
		return
	if state == State.DORMANT:
		velocity.x = 0
		move_and_slide()
		return
	if not is_instance_valid(target) or target.health <= 0:
		velocity.x = 0
		move_and_slide()
		return
	var difference := target.global_position - global_position
	_update_platform_exceptions(difference)
	match state:
		State.INTRO, State.PHASE:
			velocity.x = 0
			if clock >= (data.intro_duration if state == State.INTRO else data.phase_duration):
				_set_state(State.APPROACH)
		State.IDLE, State.PATROL:
			if difference.length() <= data.detection_range and _has_sight():
				_set_state(State.DETECT)
			elif state == State.IDLE and clock > 0.5:
				_set_state(State.PATROL)
			elif state == State.PATROL:
				if absf(global_position.x - home.x) >= data.patrol_range:
					facing = 1 if global_position.x < home.x else -1
				velocity.x = facing * data.move_speed * 0.35
		State.DETECT:
			velocity.x = 0
			if clock > 0.15:
				_set_state(State.APPROACH)
		State.APPROACH:
			facing = 1 if difference.x > 0 else -1
			if global_position.distance_to(home) > data.leash_range or difference.length() > data.leash_range:
				_set_state(State.RETURN)
			else:
				var available: Array[Resource] = []
				for profile in data.attacks:
					if profile.minimum_phase <= phase:
						available.append(profile)
				var next: Resource = available[attack_cursor % available.size()]
				velocity.x = facing * data.move_speed
				if data.behavior == "ranged" and absf(difference.x) < 220 and not test_move(global_transform, Vector2(-facing * 10, 0)):
					velocity.x = -facing * data.move_speed
				elif absf(difference.x) <= next.reach and absf(difference.y) < 90 and _has_sight():
					velocity.x = 0
					if cooldown <= 0:
						_begin_attack(next)
		State.TELEGRAPH:
			velocity.x = 0
			if clock >= attack.windup:
				_set_state(State.ATTACK)
				if attack.kind == "leap":
					velocity = launch_velocity
				elif attack.kind == "lunge":
					velocity.y = attack.leap_velocity
		State.ATTACK:
			if clock >= attack.active_time:
				velocity.x = 0
				_set_state(State.RECOVERY)
			else:
				_tick_attack()
		State.RECOVERY:
			velocity.x = 0
			if clock >= attack.recovery:
				cooldown = attack.cooldown
				_set_state(State.APPROACH)
		State.RETURN:
			velocity.x = signf(home.x - global_position.x) * data.move_speed
			if absf(home.x - global_position.x) < 12:
				velocity.x = 0
				_set_state(State.IDLE)
		State.HURT:
			velocity.x = move_toward(velocity.x, 0, 1000 * delta)
			if clock >= hurt_duration:
				_set_state(State.APPROACH)
	move_and_slide()
	if state == State.ATTACK and attack.kind == "leap" and is_on_floor() and clock > 0.10:
		impact_done = true
		velocity.x = 0
		_hit_box(attack.hit_size, Vector2(0, -attack.hit_size.y / 2))
		_set_state(State.RECOVERY)
	queue_redraw()

func _begin_attack(profile: Resource) -> void:
	attack = profile
	attack_cursor += 1
	aimed_position = Vector2(clampf(target.global_position.x, 120, 1900), global_position.y)
	if attack.kind == "leap":
		_prepare_leap()
	hit_targets.clear()
	last_burst = -1
	impact_done = false
	_set_state(State.TELEGRAPH)
	attack_started.emit(attack.attack_id)

func _prepare_leap() -> void:
	var step := 1.0 / Engine.physics_ticks_per_second
	var flight: float = -2 * attack.leap_velocity / data.gravity
	launch_velocity = Vector2((aimed_position.x - global_position.x) / flight, attack.leap_velocity)
	var predicted := global_position
	var motion := launch_velocity
	var excluded: Array[RID] = []
	for body in get_collision_exceptions():
		excluded.append(body.get_rid())
	# 当前固定关卡由矩形平台构成；采样脚底左/中/右，预告首次落地而非穿过平台后的地面。
	for frame in 120:
		if frame > 0:
			motion.y += data.gravity * step
		var next := predicted + motion * step
		if motion.y > 0:
			var landing_y := INF
			for x in [-data.body_size.x / 2 + 1, 0.0, data.body_size.x / 2 - 1]:
				var query := PhysicsRayQueryParameters2D.create(predicted + Vector2(x, 0), next + Vector2(x, 0), 1)
				query.exclude = excluded
				var hit := get_world_2d().direct_space_state.intersect_ray(query)
				if not hit.is_empty() and hit.normal.y < -0.5:
					landing_y = minf(landing_y, hit.position.y)
			if landing_y < INF:
				aimed_position = Vector2(next.x, landing_y)
				return
		predicted = next

func _update_platform_exceptions(difference: Vector2) -> void:
	for platform in dropped_platforms.duplicate():
		var shape: CollisionShape2D = platform.get_node("CollisionShape2D")
		if absf(global_position.x - platform.global_position.x) > (shape.shape.size.x + data.body_size.x) / 2 + 4:
			remove_collision_exception_with(platform)
			dropped_platforms.erase(platform)
	if state != State.APPROACH or difference.y < 60 or not is_on_floor():
		return
	for index in get_slide_collision_count():
		var body: Node = get_slide_collision(index).get_collider()
		var shape: CollisionShape2D = body.get_node_or_null("CollisionShape2D")
		if shape != null and shape.one_way_collision and not dropped_platforms.has(body):
			add_collision_exception_with(body)
			dropped_platforms.append(body)

func _tick_attack() -> void:
	match attack.kind:
		"shot", "wave":
			if not impact_done:
				impact_done = true
				_spawn_projectile(facing, attack.kind == "wave")
				if attack.kind == "wave":
					_spawn_projectile(-facing, true)
		"lunge":
			velocity.x = facing * attack.move_speed
			_hit_box(attack.hit_size, Vector2(facing * attack.hit_size.x / 2, -30))
		"melee", "slam":
			velocity.x = 0
			var pulse := mini(attack.burst - 1, floori(clock / (attack.active_time / attack.burst)))
			if pulse != last_burst:
				last_burst = pulse
				hit_targets.clear()
			var offset := Vector2(0, -attack.hit_size.y / 2) if attack.kind == "slam" else Vector2(facing * attack.hit_size.x / 2, -30)
			_hit_box(attack.hit_size, offset)

func _hit_box(size: Vector2, offset: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, global_position + offset)
	query.collision_mask = 2
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var body: Node = hit.collider
		if not hit_targets.has(body.get_instance_id()) and body.has_method("receive_hit"):
			hit_targets[body.get_instance_id()] = true
			body.receive_hit(attack.damage, Vector2(facing * 180, -100))

func _spawn_projectile(direction: int, wave: bool) -> void:
	var projectile := Node2D.new()
	projectile.set_script(Projectile)
	projectile.source = self
	projectile.velocity = Vector2(direction * attack.projectile_speed, 0)
	projectile.damage = attack.damage
	projectile.ground_wave = wave
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector2(direction * 25, -8 if wave else -32)

func receive_hit(amount: float, impulse: Vector2, armor_damage: float = 0.0) -> bool:
	if state in [State.DORMANT, State.INTRO, State.PHASE, State.DEAD] or amount <= 0:
		return false
	var broken := armor > 0 and armor_damage >= armor
	var reduction: float = data.armor_reduction if armor > 0 else 0.0
	health = maxi(0, health - Damage.resolve(amount * (1 - reduction), 0))
	armor = maxf(0, armor - armor_damage)
	if health == 0:
		collision_layer = 0
		_set_state(State.DEAD)
		reward_requested.emit({"source_id": source_id, "enemy_id": data.enemy_id, "guaranteed_material": "筑基灵髓" if data.behavior == "boss" else "", "drop_rates_defined": false, "reward_tags": ["丹田灵气", "灵石", "装备或材料"], "amounts_defined": false})
		died.emit(source_id)
	elif phase == 1 and data.phase_health > 0 and health <= data.max_health * data.phase_health:
		phase = 2
		velocity.x = 0
		_set_state(State.PHASE)
		phase_changed.emit(phase)
	elif broken or not ((data.behavior == "boss" or armor > 0) and state in [State.TELEGRAPH, State.ATTACK]):
		velocity = impulse
		hurt_duration = data.armor_break_stun if broken else data.hit_stun
		_set_state(State.HURT)
	queue_redraw()
	return true

func _draw() -> void:
	if data == null:
		return
	var color := Color("9e8270")
	if data.behavior in ["ghost", "ranged"]:
		color = Color("83dce8")
	elif data.behavior in ["elite", "boss"]:
		color = Color("b89a60")
	if state == State.HURT:
		color = Color("9e302a")
	if show_placeholder_body:
		draw_rect(Rect2(Vector2(-data.body_size.x / 2, -data.body_size.y), data.body_size), color)
		draw_line(Vector2(0, -35), Vector2(facing * 32, -30), Color.WHITE, 3)
	draw_rect(Rect2(-40, -data.body_size.y - 12, 80, 5), Color("315461"))
	draw_rect(Rect2(-40, -data.body_size.y - 12, 80.0 * health / data.max_health, 5), Color("83dce8"))
	if state in [State.TELEGRAPH, State.ATTACK]:
		var warning := Color(0.72, 0.60, 0.38, 0.30) if state == State.TELEGRAPH else Color(0.62, 0.19, 0.16, 0.45)
		var offset := Vector2(facing * attack.hit_size.x / 2, -30)
		if attack.kind in ["slam", "leap"]:
			offset = Vector2(aimed_position.x - global_position.x if attack.kind == "leap" else 0.0, -attack.hit_size.y / 2)
			if attack.kind == "leap":
				offset.y += aimed_position.y - global_position.y
		if attack.kind in ["shot", "wave"]:
			draw_line(Vector2(-facing * attack.reach if attack.kind == "wave" else 0.0, -8 if attack.kind == "wave" else -32), Vector2(facing * attack.reach, -8 if attack.kind == "wave" else -32), warning, 6)
		else:
			draw_rect(Rect2(offset - attack.hit_size / 2, attack.hit_size), warning)
