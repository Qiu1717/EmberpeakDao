extends RefCounted

const INK := Color("07141b")
const PAPER := Color("d7e2e2")
const GOLD := Color("b89a60")

static func theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	result.default_font = font
	result.default_font_size = 18
	result.set_color("font_color", "Label", PAPER)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("153642") if state in ["hover", "focus"] else Color("0d2029")
		box.border_color = GOLD if state == "focus" else Color("315461")
		box.set_border_width_all(1)
		box.set_corner_radius_all(3)
		box.content_margin_left = 18
		box.content_margin_right = 18
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		result.set_stylebox(state, "Button", box)
	result.set_color("font_color", "Button", PAPER)
	result.set_color("font_disabled_color", "Button", Color("596a6f"))
	return result

static func label(parent: Node, text: String, size: int = 18) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	parent.add_child(result)
	return result

static func button(parent: Node, text: String, id: String, action: Callable, scope: Node) -> Button:
	var result := Button.new()
	result.name = id
	result.text = text
	result.custom_minimum_size.y = 44
	parent.add_child(result)
	result.owner = scope
	result.unique_name_in_owner = true
	if action.is_valid():
		result.pressed.connect(action)
	return result

static func centered_box(scope: Control, width: float = 360) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = width
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	return box
