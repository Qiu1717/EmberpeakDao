extends Control
## 场景原图只作静态背景，不从画面推导建筑碰撞。
const Catalog := preload("res://scripts/art/art_catalog.gd")
var art_id := ""
var artwork: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_art("sword_entry")

func set_art(id: String) -> void:
	art_id = id
	artwork = Catalog.texture(id)
	queue_redraw()

func _draw() -> void:
	if artwork != null:
		var factor := maxf(size.x / artwork.get_width(), size.y / artwork.get_height())
		var extent := artwork.get_size() * factor
		draw_texture_rect(artwork, Rect2((size - extent) / 2, extent), false, Color(0.62, 0.68, 0.72))
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("07141b"))
	for layer in 3:
		var points := PackedVector2Array([Vector2(0, size.y)])
		for index in 13:
			var x := size.x * float(index) / 12.0
			var y := size.y * (0.40 + layer * 0.14 + sin(index * 1.7 + layer) * 0.12)
			points.append(Vector2(x, y))
		points.append(Vector2(size.x, size.y))
		draw_colored_polygon(points, [Color("0d2029"), Color("102b35"), Color("153642")][layer])
	draw_circle(Vector2(size.x * 0.23, size.y * 0.23), 42.0, Color("315461"))
	draw_line(Vector2(48, size.y - 48), Vector2(size.x - 48, size.y - 48), Color("315461"))
