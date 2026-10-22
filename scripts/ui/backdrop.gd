extends Control
## 纯绘制的菜单背景，不构成可探索地图。

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
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
