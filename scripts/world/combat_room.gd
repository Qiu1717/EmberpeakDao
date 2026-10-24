extends Node2D
signal cleared(room_id: String)
signal reward_requested(payload: Dictionary)
const PaintedMap := preload("res://scripts/world/painted_map.gd")
@export var map_id := ""
var map: Node2D
var active_player: CharacterBody2D
var entry_point := Vector2.ZERO
var exit_point := Vector2.ZERO
var altar_point := Vector2.ZERO
const Enemy := preload("res://scenes/enemies/enemy.tscn")
@export var room_id := ""
@export var display_name := ""
@export var platforms: Array[Rect2] = []
@export var enemy_data: Array[Resource] = []
@export var enemy_positions := PackedVector2Array()
var enemies: Array[Node] = []
var alive := 0
var is_cleared := false
var settled: Dictionary = {}

func _ready() -> void:
	if not map_id.is_empty():
		map = Node2D.new()
		map.name = "PaintedMap"
		map.set_script(PaintedMap)
		add_child(map)
		map.build(map_id)
		entry_point = map.layout.spawn
		exit_point = map.layout["return"]
		altar_point = map.layout.altar
		# 只保留原图有明确上沿的断阶岛与祭坛；不增加悬空矩形。
		platforms.assign([map.layout.platform] if map.layout.has("platform") else [])
		_build_body(Rect2(-20, -200, 20, 1400), "LeftWall")
		_build_body(Rect2(1672, -200, 20, 1400), "RightWall")
		_build_body(Rect2(exit_point.x - 45, exit_point.y - 240, 24, 240), "ExitGate")
		_build_body(Rect2(45, entry_point.y - 240, 24, 240), "EntryGate")
		return
	_build_body(Rect2(0, 640, 2200, 120), "Ground")
	_build_body(Rect2(-20, -200, 20, 1000), "LeftWall")
	_build_body(Rect2(2200, -200, 20, 1000), "RightWall")
	for index in platforms.size():
		_build_body(platforms[index], "Platform%d" % index, true)
	_build_body(Rect2(1990, 380, 24, 260), "ExitGate")
	_build_body(Rect2(40, 380, 24, 260), "EntryGate")

func _build_body(rect: Rect2, id: String, one_way: bool = false) -> void:
	var body := StaticBody2D.new()
	body.name = id
	body.position = rect.get_center()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	collision.one_way_collision = one_way
	body.add_child(collision)
	add_child(body)

func enter(player: CharacterBody2D, was_cleared: bool, enemy_states: Dictionary = {}, enemy_armor: Dictionary = {}) -> void:
	active_player = player
	if not was_cleared:
		for index in enemy_data.size():
			var source := room_id + ":" + str(index)
			if enemy_states.get(source, 1) == 0:
				continue
			var enemy: Node = Enemy.instantiate()
			enemy.data = enemy_data[index]
			enemy.source_id = source
			enemy.position = enemy_positions[index]
			add_child(enemy)
			enemies.append(enemy)
			enemy.reward_requested.connect(func(payload: Dictionary): reward_requested.emit(payload))
			enemy.died.connect(_on_enemy_died)
			enemy.activate(player)
			if enemy_states.has(source):
				# 恢复状态不走伤害公式，避免护甲再减一次伤害或Boss入场拒绝。
				enemy.health = int(enemy_states[source])
				enemy.armor = float(enemy_armor.get(source, enemy.armor))
				enemy.phase = 2 if enemy.data.phase_health > 0 and enemy.health <= enemy.data.max_health * enemy.data.phase_health else 1
	alive = enemies.size()
	if alive == 0:
		_unlock()

func _on_enemy_died(source: String) -> void:
	if settled.has(source):
		return
	settled[source] = true
	alive -= 1
	if alive == 0:
		_unlock()

func _unlock() -> void:
	if is_cleared:
		return
	is_cleared = true
	for id in ["EntryGate", "ExitGate"]:
		get_node(id + "/CollisionShape2D").set_deferred("disabled", true)
	cleared.emit(room_id)
	queue_redraw()

func _draw() -> void:
	if not map_id.is_empty():
		var color := Color("b89a60") if is_cleared else Color("9e302a")
		for id in ["EntryGate", "ExitGate"]:
			var gate: Node2D = get_node(id)
			draw_rect(Rect2(gate.position - Vector2(12, 120), Vector2(24, 240)), color, false, 2)
			if not is_cleared:
				for offset in [-6, 0, 6]:
					draw_line(gate.position + Vector2(offset, -120), gate.position + Vector2(offset, 120), color, 2)
		return
	draw_rect(Rect2(0, 640, 2200, 120), Color("102b35"))
	draw_line(Vector2(0, 640), Vector2(2200, 640), Color("83dce8"), 2)
	for platform in platforms:
		draw_rect(platform, Color("153642"))
		draw_line(platform.position, platform.position + Vector2(platform.size.x, 0), Color("83dce8"), 2)
	for x in [52, 2002]:
		draw_rect(Rect2(x - 12, 380, 24, 260), Color("315461") if is_cleared else Color("9e302a"), not is_cleared, 3 if is_cleared else -1)
	# 临时剑冢轮廓，不宣称正式手绘场景。
	for x in range(320, 1900, 210):
		draw_line(Vector2(x, 640), Vector2(x - 18, 594), Color("315461"), 4)
	if room_id == "altar":
		draw_rect(Rect2(950, 616, 100, 24), Color("b89a60"))
		draw_circle(Vector2(1000, 584), 18, Color("83dce8"))

func _physics_process(_delta: float) -> void:
	if map == null:
		return
	if is_instance_valid(active_player) and active_player.position.y > 1080 and active_player.health > 0:
		# 坠落沿用已有死亡事件；无敌闪避结束后仍会结算。
		active_player.receive_hit(100000, Vector2.ZERO)
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.health > 0 and enemy.state in [enemy.State.IDLE, enemy.State.PATROL, enemy.State.DETECT, enemy.State.APPROACH, enemy.State.RETURN, enemy.State.TELEGRAPH]:
			for surface in map.layout.surfaces:
				var left: Vector2 = surface[0]
				var right: Vector2 = surface[-1]
				if enemy.position.x >= left.x - 10 and enemy.position.x <= right.x + 10 and absf(enemy.position.y - map.floor_at(clampf(enemy.position.x, left.x, right.x))) < 10:
					# 普通追击留在脚下石台；攻击跃击和受击仍可离台。
					enemy.position.x = clampf(enemy.position.x, left.x + 28, right.x - 28)
		if is_instance_valid(enemy) and enemy.health > 0 and enemy.position.y > 1080:
			enemy.receive_hit(100000, Vector2.ZERO)
