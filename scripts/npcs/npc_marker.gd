extends Node2D
## 临时世界交互点；完整概念肖像只在对话中展示，不充当角色动画。
const Ui := preload("res://scripts/ui/ui_style.gd")
var display_name := ""

func _ready() -> void:
	var label := Label.new()
	label.theme = Ui.theme()
	label.text = display_name + " · 交互\n临时交互点"
	label.position = Vector2(-75, -108)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(0, -55), Ui.GOLD, 2)
	draw_circle(Vector2(0, -64), 9, Ui.GOLD, false, 2)
