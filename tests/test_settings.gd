extends SceneTree
## 使用真实界面与文件系统，结束时还原用户设置，避免测试污染。

var settings: Node
var original: Dictionary
var backup := PackedByteArray()
var had_file := false
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("FAIL: " + message)
		_finish(1)
		return false
	checks += 1
	print("PASS: " + message)
	return true

func _frames() -> void:
	for index in 6:
		await process_frame

func _click(button: Button) -> void:
	button.grab_focus()
	await _frames()
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames()

func _key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames()

func _finish(code: int) -> void:
	settings.apply_options(original)
	if had_file:
		var file := FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
		file.store_buffer(backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.SETTINGS_PATH))
	quit(code)

func _run() -> void:
	settings = root.get_node("Settings")
	original = settings.values.duplicate(true)
	had_file = FileAccess.file_exists(settings.SETTINGS_PATH)
	if had_file:
		backup = FileAccess.get_file_as_bytes(settings.SETTINGS_PATH)
	change_scene_to_file("res://scenes/main/main_menu.tscn")
	await _frames()
	await _click(current_scene.get_node("%Settings"))
	var panel: Control = current_scene.get_node("SettingsMenu")
	panel.sliders.master_volume.value = 23
	await _click(panel.get_node("%Apply"))
	if not _check(is_equal_approx(settings.values.master_volume, 0.23), "设置界面应用音量"):
		return
	var config := ConfigFile.new()
	var error: int = config.load(settings.SETTINGS_PATH)
	if not _check(error == OK and is_equal_approx(config.get_value("preferences", "values").master_volume, 0.23), "应用按钮实际写入用户设置文件"):
		return
	await _click(panel.binding_buttons.move_left)
	await _key(KEY_Z)
	await _click(panel.get_node("%Apply"))
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Z
	if not _check(InputMap.event_is_action(event, "move_left"), "界面捕获新按键并应用"):
		return
	await _click(panel.binding_buttons.move_left)
	await _key(KEY_J)
	if not _check(panel.draft.bindings.move_left == KEY_Z, "界面拒绝与普攻冲突的按键"):
		return
	panel.sliders.master_volume.value = 99
	await _click(panel.get_node("%Close"))
	if not _check(is_equal_approx(settings.values.master_volume, 0.23), "关闭设置放弃未应用修改"):
		return
	if not _check(root.gui_get_focus_owner() == current_scene.get_node("%Settings"), "关闭后恢复设置按钮焦点"):
		return
	var display: Dictionary = settings.values.duplicate(true)
	display.window_size = Vector2i(1600, 900)
	display.vsync = false
	settings.apply_options(display)
	await create_timer(0.25).timeout
	if DisplayServer.get_name() != "headless":
		if not _check(DisplayServer.window_get_size() == Vector2i(1600, 900), "窗口分辨率实际切换到1600×900"):
			return
		if not _check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "垂直同步实际关闭"):
			return
	display.fullscreen = true
	settings.apply_options(display)
	await create_timer(0.25).timeout
	if DisplayServer.get_name() != "headless":
		if not _check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "实际进入全屏"):
			return
	display.fullscreen = false
	settings.apply_options(display)
	await create_timer(0.25).timeout
	if DisplayServer.get_name() != "headless":
		if not _check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "实际返回窗口模式"):
			return
	print("SETTINGS_CHECKS_PASSED=", checks)
	_finish(0)
