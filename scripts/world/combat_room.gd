extends Node2D
signal cleared(room_id: String)
signal reward_requested(payload: Dictionary)
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

func enter(player: CharacterBody2D, was_cleared: bool) -> void:
	if not was_cleared:
		for index in enemy_data.size():
			var enemy: Node = Enemy.instantiate()
			enemy.data = enemy_data[index]
			enemy.source_id = room_id + ":" + str(index)
			enemy.position = enemy_positions[index]
			add_child(enemy)
			enemies.append(enemy)
			enemy.reward_requested.connect(func(payload: Dictionary): reward_requested.emit(payload))
			enemy.died.connect(_on_enemy_died)
			enemy.activate(player)
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
