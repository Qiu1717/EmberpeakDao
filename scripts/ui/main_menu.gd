extends Control
@onready var app: Node = get_node("/root/App")

const Ui := preload("res://scripts/ui/ui_style.gd")
const SettingsMenu := preload("res://scenes/ui/settings_menu.tscn")

func _ready() -> void:
	theme = Ui.theme()
	app.enter_menu()
	var box := Ui.centered_box(self, 340)
	var title := Ui.label(box, "烬山问道", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Ui.GOLD)
	var subtitle := Ui.label(box, "灵脉虽烬，问道不息", 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.label(box, "", 12)
	Ui.button(box, "开始新游戏", "NewGame", app.start_new_game, self)
	var resume := Ui.button(box, "继续游戏", "Continue", Callable(), self)
	resume.disabled = true
	resume.tooltip_text = "游戏存档尚未接入，当前没有可继续的探索。"
	var settings_panel: Control = SettingsMenu.instantiate()
	settings_panel.name = "SettingsMenu"
	Ui.button(box, "设置", "Settings", settings_panel.show_menu, self)
	Ui.button(box, "退出游戏", "Quit", app.quit_game, self)
	add_child(settings_panel)
	settings_panel.visibility_changed.connect(func():
		box.visible = not settings_panel.visible
		if box.is_visible_in_tree():
			get_node("%Settings").grab_focus()
	)
	get_node("%NewGame").grab_focus()
