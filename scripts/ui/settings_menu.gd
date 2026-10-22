extends Control
@onready var settings: Node = get_node("/root/Settings")

const Ui := preload("res://scripts/ui/ui_style.gd")
var sliders: Dictionary = {}
var binding_buttons: Dictionary = {}
var draft: Dictionary
var listening: String = ""
var fullscreen: CheckButton
var vsync: CheckButton
var resolution: OptionButton
var status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = Ui.theme()
	var box := Ui.centered_box(self, 640)
	Ui.label(box, "设置", 32)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 360
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	for entry in [["总音量", "master_volume"], ["音乐", "music_volume"], ["音效", "sfx_volume"]]:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var title := Ui.label(row, entry[0])
		title.custom_minimum_size.x = 160
		var slider := HSlider.new()
		slider.max_value = 100
		slider.step = 1
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		sliders[entry[1]] = slider
	fullscreen = CheckButton.new()
	fullscreen.text = "全屏显示"
	rows.add_child(fullscreen)
	vsync = CheckButton.new()
	vsync.text = "垂直同步"
	rows.add_child(vsync)
	Ui.label(rows, "窗口分辨率（全屏时采用屏幕尺寸）", 16)
	resolution = OptionButton.new()
	for size in settings.SIZES:
		resolution.add_item("%d × %d" % [size.x, size.y])
	rows.add_child(resolution)
	Ui.label(rows, "键位设置 · 鼠标与手柄默认映射保留", 16)
	for action in settings.ACTION_LABELS:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var title := Ui.label(row, settings.ACTION_LABELS[action])
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := Button.new()
		button.custom_minimum_size.x = 170
		button.pressed.connect(_listen.bind(action))
		row.add_child(button)
		binding_buttons[action] = button
	status = Ui.label(box, "调整后点击应用；关闭将放弃未应用修改。", 16)
	Ui.button(box, "应用并保存", "Apply", _apply, self)
	Ui.button(box, "恢复默认", "Defaults", func(): _populate(settings.defaults()), self)
	Ui.button(box, "关闭", "Close", close_menu, self)
	hide()

func show_menu() -> void:
	_populate(settings.values)
	show()
	get_node("%Close").grab_focus()

func _populate(options: Dictionary) -> void:
	draft = options.duplicate(true)
	listening = ""
	for key in sliders:
		sliders[key].value = draft[key] * 100.0
	fullscreen.button_pressed = draft.fullscreen
	vsync.button_pressed = draft.vsync
	resolution.select(settings.SIZES.find(draft.window_size))
	_refresh_bindings()
	status.text = "调整后点击应用；Esc 关闭当前设置。"

func _refresh_bindings() -> void:
	for action in binding_buttons:
		binding_buttons[action].text = OS.get_keycode_string(draft.bindings[action])

func _listen(action: String) -> void:
	listening = action
	status.text = "请按新按键；Esc 取消。"

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if listening.is_empty():
		if (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and not event.is_echo():
			close_menu()
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.physical_keycode != KEY_ESCAPE:
		var candidate := draft.duplicate(true)
		candidate.bindings[listening] = int(event.physical_keycode)
		if settings.validate_options(candidate):
			draft = candidate
			status.text = "按键已选择，点击应用后生效。"
		else:
			status.text = "按键已被使用或保留，请选择其他按键。"
	else:
		status.text = "已取消改键。"
	listening = ""
	_refresh_bindings()

func _apply() -> void:
	for key in sliders:
		draft[key] = sliders[key].value / 100.0
	draft.fullscreen = fullscreen.button_pressed
	draft.vsync = vsync.button_pressed
	draft.window_size = settings.SIZES[resolution.selected]
	if not settings.apply_options(draft):
		status.text = "设置无效，请检查按键是否冲突。"
		return
	var error: int = settings.save_options()
	status.text = "设置已保存。" if error == OK else "保存失败：" + error_string(error)

func close_menu() -> void:
	listening = ""
	hide()
