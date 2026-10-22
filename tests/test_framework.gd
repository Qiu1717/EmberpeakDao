extends SceneTree

var checks: int = 0
var app: Node
var settings: Node

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("FAIL: " + message)
		quit(1)
		return false
	checks += 1
	print("PASS: " + message)
	return true

func _frames(count: int = 4) -> void:
	for index in count:
		await process_frame

func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames()

func _escape() -> void:
	await _press_key(KEY_ESCAPE)

func _press_key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames()

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="):
			var folder := argument.trim_prefix("--screenshots=")
			DirAccess.make_dir_recursive_absolute(folder)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join(label + ".png"))

func _run() -> void:
	if not _check(ResourceLoader.exists("res://scenes/main/main_menu.tscn"), "主菜单场景存在"):
		return
	app = root.get_node("App")
	settings = root.get_node("Settings")
	if not _check(change_scene_to_file("res://scenes/main/main_menu.tscn") == OK, "加载主菜单"):
		return
	await _frames()
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		for index in 60:
			if root.has_focus():
				break
			await process_frame
		await _frames()
	if not _check(current_scene.get_node("%Continue").disabled, "没有存档时继续不可用"):
		return
	await _capture("main_menu")
	await _click(current_scene.get_node("%Settings"))
	var panel: Control = current_scene.get_node("SettingsMenu")
	if not _check(panel.visible, "设置按钮打开设置"):
		return
	var focus_stays_inside := true
	for index in 14:
		await _press_key(KEY_TAB)
		focus_stays_inside = focus_stays_inside and panel.is_ancestor_of(root.gui_get_focus_owner())
	if not _check(focus_stays_inside, "设置层键盘焦点不会进入背后菜单"):
		return
	await _capture("settings")
	await _escape()
	if not _check(not panel.visible and not paused, "Esc 关闭设置且不暂停主菜单"):
		return
	var original: Dictionary = settings.values.duplicate(true)
	var changed: Dictionary = original.duplicate(true)
	changed.master_volume = 0.37
	changed.bindings.move_left = KEY_Z
	if not _check(settings.apply_options(changed), "设置应用成功"):
		return
	if not _check(is_equal_approx(AudioServer.get_bus_volume_linear(0), 0.37), "音量实际作用于音频总线"):
		return
	var test_path := "user://framework_test_settings.cfg"
	if not _check(settings.save_options(test_path) == OK, "设置保存至独立测试文件"):
		return
	settings.apply_options(original)
	if not _check(settings.load_options(test_path) == OK and is_equal_approx(settings.values.master_volume, 0.37), "设置从磁盘重载"):
		return
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Z
	if not _check(InputMap.event_is_action(key, "move_left"), "重绑定实际修改输入映射"):
		return
	changed.bindings.move_left = changed.bindings.heavy_attack
	if not _check(not settings.apply_options(changed), "冲突绑定被拒绝"):
		return
	settings.apply_options(original)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	await _click(current_scene.get_node("%NewGame"))
	if not _check(current_scene.scene_file_path == "res://scenes/world/game.tscn" and app.state == app.State.PLAYING, "新游戏进入真实游戏场景"):
		return
	var game: Node = current_scene
	if not _check(game.get_node("UI/Overlay").size.x >= root.get_visible_rect().size.x, "游戏界面覆盖完整视口"):
		return
	var marker := Timer.new()
	marker.wait_time = 0.01
	marker.one_shot = false
	game.add_child(marker)
	var ticks := [0]
	marker.timeout.connect(func(): ticks[0] += 1)
	marker.start()
	await create_timer(0.06).timeout
	await _capture("game")
	await _escape()
	if not _check(paused and game.get_node("PauseMenu").visible, "Esc 暂停并显示菜单"):
		return
	var before: int = ticks[0]
	await create_timer(0.08).timeout
	if not _check(ticks[0] == before, "暂停实际冻结游戏子节点"):
		return
	await _capture("pause")
	await _click(game.get_node("PauseMenu/%Settings"))
	if not _check(paused and game.get_node("PauseMenu/SettingsMenu").visible, "暂停中可操作设置"):
		return
	await _escape()
	if not _check(paused and not game.get_node("PauseMenu/SettingsMenu").visible, "设置层 Esc 只关闭设置"):
		return
	await _click(game.get_node("PauseMenu/%Resume"))
	if not _check(not paused and not game.get_node("PauseMenu").visible, "继续按钮恢复游戏"):
		return
	await create_timer(0.06).timeout
	if not _check(ticks[0] > before, "恢复后游戏节点继续运行"):
		return
	await _click(game.get_node("%Pause"))
	await _click(game.get_node("PauseMenu/%MainMenu"))
	if not _check(not paused and current_scene.scene_file_path == "res://scenes/main/main_menu.tscn", "暂停中返回主菜单并清除暂停"):
		return
	await _click(current_scene.get_node("%NewGame"))
	await _escape()
	await _escape()
	if not _check(not paused and app.state == app.State.PLAYING, "重复场景切换后 Esc 仍可暂停恢复"):
		return
	var tab_binding: Dictionary = original.duplicate(true)
	tab_binding.bindings.pause = KEY_TAB
	settings.apply_options(tab_binding)
	await _press_key(KEY_TAB)
	if not _check(paused, "暂停重绑为 Tab 后仍优先于 GUI 导航生效"):
		return
	await _press_key(KEY_TAB)
	if not _check(not paused, "重绑后的暂停键可以恢复"):
		return
	settings.apply_options(original)
	await _escape()
	await _click(current_scene.get_node("PauseMenu/%MainMenu"))
	print("FRAMEWORK_CHECKS_PASSED=", checks)
	if "--quit-from-pause" in OS.get_cmdline_user_args():
		await _click(current_scene.get_node("%NewGame"))
		await _escape()
		current_scene.get_node("PauseMenu/%Quit").pressed.emit()
	else:
		current_scene.get_node("%Quit").pressed.emit()
