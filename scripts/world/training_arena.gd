extends Node2D

const Player := preload("res://scenes/player/player.tscn")
const Target := preload("res://scripts/world/training_target.gd")
var platforms := [Rect2(-300, 640, 2800, 100), Rect2(600, 540, 220, 24), Rect2(900, 440, 180, 24), Rect2(1300, 540, 220, 24), Rect2(-20, -200, 20, 1000), Rect2(2200, -200, 20, 1000)]

func _ready() -> void:
	for rect in platforms:
		var body := StaticBody2D.new()
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		body.position = rect.get_center()
		body.add_child(collision)
		add_child(body)
	var player: CharacterBody2D = Player.instantiate()
	player.position = Vector2(280, 640)
	add_child(player)
	var target := CharacterBody2D.new()
	target.set_script(Target)
	target.name = "Target"
	target.collision_layer = 4
	target.collision_mask = 1
	target.position = Vector2(450, 640)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 60)
	collider.shape = shape
	collider.position.y = -30
	target.add_child(collider)
	add_child(target)

func _draw() -> void:
	for rect in platforms:
		draw_rect(rect, Color("153642"))
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("83dce8"), 2)
