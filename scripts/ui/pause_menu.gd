extends Control
@onready var app: Node = get_node("/root/App")

const Ui := preload("res://scripts/ui/ui_style.gd")
const SettingsMenu := preload("res://scenes/ui/settings_menu.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = Ui.theme()
	var box := Ui.centered_box(self)
	var title := Ui.label(box, "暂歇片刻", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.button(box, "继续游戏", "Resume", func(): app.set_paused(false), self)
	var settings_panel: Control = SettingsMenu.instantiate()
	settings_panel.name = "SettingsMenu"
	Ui.button(box, "设置", "Settings", settings_panel.show_menu, self)
	Ui.button(box, "返回主菜单", "MainMenu", app.return_to_menu, self)
	Ui.button(box, "退出游戏", "Quit", app.quit_game, self)
	add_child(settings_panel)
	settings_panel.visibility_changed.connect(func():
		box.visible = not settings_panel.visible
		if box.is_visible_in_tree():
			get_node("%Settings").grab_focus()
	)
	app.state_changed.connect(_on_state_changed)
	_on_state_changed(app.state)

func _on_state_changed(state: int) -> void:
	visible = state == app.State.PAUSED
	if visible:
		get_node("%Resume").grab_focus()
	else:
		$SettingsMenu.hide()
