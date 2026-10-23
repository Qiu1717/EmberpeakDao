extends Node2D
# 原图像素即世界坐标；轮廓取前景石台的可落脚上沿。
const SIZE := Vector2(1672, 941)
const LAYOUTS := {
	"sword_entry": {"surfaces": [[Vector2(0, 644), Vector2(450, 644), Vector2(680, 672), Vector2(1090, 690), Vector2(1672, 700)]], "jump_from": Vector2(320, 644), "spawn": Vector2(140, 644), "return": Vector2(1570, 699), "altar": Vector2.ZERO},
	"broken_swords": {"surfaces": [[Vector2(0, 640), Vector2(450, 678), Vector2(950, 690), Vector2(1300, 702), Vector2(1672, 696)]], "jump_from": Vector2(650, 682.8), "spawn": Vector2(140, 652), "return": Vector2(1570, 698), "altar": Vector2.ZERO},
	"stepped_corridor": {"surfaces": [[Vector2(0, 690), Vector2(865, 690)], [Vector2(1010, 580), Vector2(1245, 580)], [Vector2(1360, 620), Vector2(1672, 620)]], "platform": Rect2(1010, 580, 235, 20), "jump_from": Vector2(1380, 620), "spawn": Vector2(140, 690), "return": Vector2(1570, 620), "altar": Vector2.ZERO},
	"elite_den": {"surfaces": [[Vector2(0, 610), Vector2(450, 615), Vector2(1000, 620), Vector2(1672, 622)]], "jump_from": Vector2(640, 616.727), "spawn": Vector2(140, 612), "return": Vector2(1570, 622), "altar": Vector2.ZERO},
	"spirit_altar": {"surfaces": [[Vector2(0, 688), Vector2(730, 697), Vector2(820, 630), Vector2(1025, 630), Vector2(1090, 697), Vector2(1672, 700)]], "platform": Rect2(820, 630, 205, 20), "jump_from": Vector2(780, 660), "spawn": Vector2(140, 690), "return": Vector2(1570, 700), "altar": Vector2(920, 630)},
	"general_hall": {"surfaces": [[Vector2(0, 675), Vector2(520, 673), Vector2(1100, 675), Vector2(1672, 680)]], "jump_from": Vector2(800, 673.966), "spawn": Vector2(140, 675), "return": Vector2(1570, 679), "altar": Vector2.ZERO}
}
var layout: Dictionary
var map_id := ""
func build(id: String) -> void:
	map_id = id
	layout = LAYOUTS[id]
	var texture: Texture2D = load("res://assets/backgrounds/nameless_tomb/" + id + ".png")
	var background := Sprite2D.new()
	background.name = "Background_Far"
	background.texture = texture
	background.centered = false
	background.z_index = -30
	add_child(background)
	for index in layout.surfaces.size():
		var line := PackedVector2Array(layout.surfaces[index])
		var polygon := line.duplicate()
		polygon.append(Vector2(line[-1].x, 941))
		polygon.append(Vector2(line[0].x, 941))
		_textured_polygon(texture, polygon, "Gameplay%d" % index, -10)
		var body := StaticBody2D.new()
		body.name = "Ground%d" % index
		var collision := CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		collision.polygon = polygon
		body.add_child(collision)
		add_child(body)
	# 前景仅遮脚下深处，不遮战斗动作；UV保持原图坐标。
	_textured_polygon(texture, PackedVector2Array([Vector2(0, 860), Vector2(1672, 860), SIZE, Vector2(0, 941)]), "Foreground", 20)
func _textured_polygon(texture: Texture2D, polygon: PackedVector2Array, id: String, layer: int) -> void:
	var art := Polygon2D.new()
	art.name = id
	art.polygon = polygon
	art.uv = polygon
	art.texture = texture
	art.z_index = layer
	add_child(art)
func floor_at(x: float) -> float:
	for surface in layout.surfaces:
		for index in range(surface.size() - 1):
			var a: Vector2 = surface[index]
			var b: Vector2 = surface[index + 1]
			if x >= a.x and x <= b.x:
				return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return 1200.0
