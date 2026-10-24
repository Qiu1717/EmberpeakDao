extends Control
@onready var app: Node = get_node("/root/App")

const Ui := preload("res://scripts/ui/ui_style.gd")
const SettingsMenu := preload("res://scenes/ui/settings_menu.tscn")
var save_message: Label

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
	Ui.button(box, "问道残庭", "Home", app.return_to_home, self)
	Ui.button(box, "剑术训练场", "Training", app.start_training, self)
	Ui.button(box, "固定路线测试", "FixedRoute", app.start_fixed_route, self)
	Ui.button(box, "山魈美术样板", "ArtRoom", app.start_art_room, self)
	Ui.button(box, "美术图鉴", "Gallery", app.start_gallery, self)
	var session: Node = get_node("/root/Session")
	var resume := Ui.button(box, "继续游戏", "Continue", app.continue_game, self)
	resume.disabled = not session.can_continue()
	resume.tooltip_text = "继续最近成功保存的探索；快照中的未记录资源死亡仍丢失。" if not resume.disabled else "当前没有可继续的有效探索。"
	get_node("%NewGame").tooltip_text = "以现有永久境界开启新探索，放弃上次探索的未记录内容。"
	save_message = Ui.label(box, session.message if session.blocked or session.message.contains("备份") else "", 14)
	save_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	session.feedback.connect(_save_feedback)
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

func _save_feedback(text: String) -> void:
	save_message.text = text
