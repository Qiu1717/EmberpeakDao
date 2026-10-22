extends SceneTree
## 由外部测试命令备份并还原设置；读写发生在两个独立 Godot 进程。

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("SETTINGS_FILE=", ProjectSettings.globalize_path("user://settings.cfg"))
	var settings: Node = root.get_node("Settings")
	var arguments := OS.get_cmdline_user_args()
	if "--write" in arguments:
		var options: Dictionary = settings.values.duplicate(true)
		options.master_volume = 0.31
		options.bindings.jump = KEY_R
		if not settings.apply_options(options) or settings.save_options() != OK:
			quit(1)
			return
		print("RESTART_WRITE_OK")
	elif "--read" in arguments:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_R
		if not is_equal_approx(settings.values.master_volume, 0.31) or not InputMap.event_is_action(event, "jump"):
			push_error("重启未恢复音量与按键")
			quit(1)
			return
		print("RESTART_READ_OK")
	quit()
