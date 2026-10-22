extends Control
@onready var app: Node = get_node("/root/App")

const Ui := preload("res://scripts/ui/ui_style.gd")

func _ready() -> void:
	var overlay := $UI/Overlay
	overlay.theme = Ui.theme()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	overlay.add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var top := HBoxContainer.new()
	layout.add_child(top)
	var title := Ui.label(top, "问道残庭", 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pause_button := Ui.button(top, "暂停", "Pause", func(): app.set_paused(true), self)
	app.state_changed.connect(func(state: int): pause_button.disabled = state == app.State.PAUSED)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(space)
	Ui.label(layout, "山门静候，问道之路尚未开启。", 22)
	Ui.label(layout, "按暂停键打开菜单", 16)
	app.log_event("游戏场景", "世界、角色与 HUD 接入节点已就绪")
