extends Node
## 用户设置独立保存，不提供游戏存档或继续探索能力。

signal changed
const SETTINGS_PATH := "user://settings.cfg"
const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const ACTION_LABELS := {
	"move_left": "向左移动", "move_right": "向右移动", "jump": "跳跃",
	"attack": "普通攻击", "heavy_attack": "重击", "dodge": "闪避",
	"skill": "主动技能", "heal": "使用药品", "interact": "交互", "pause": "暂停",
}
const DEFAULT_BINDINGS := {
	"move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE,
	"attack": KEY_J, "heavy_attack": KEY_K, "dodge": KEY_SHIFT,
	"skill": KEY_Q, "heal": KEY_E, "interact": KEY_F, "pause": KEY_ESCAPE,
}
var values: Dictionary

func defaults() -> Dictionary:
	return {"master_volume": 0.8, "music_volume": 0.8, "sfx_volume": 0.8,
		"fullscreen": false, "window_size": SIZES[0], "vsync": true,
		"bindings": DEFAULT_BINDINGS.duplicate()}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_options(defaults())
	if FileAccess.file_exists(SETTINGS_PATH):
		var error := load_options()
		if error != OK:
			push_warning("设置读取失败，使用默认设置：" + error_string(error))

func validate_options(options: Dictionary) -> bool:
	for key in ["master_volume", "music_volume", "sfx_volume"]:
		if typeof(options.get(key)) not in [TYPE_FLOAT, TYPE_INT]:
			return false
		if not is_finite(float(options[key])) or options[key] < 0.0 or options[key] > 1.0:
			return false
	for key in ["fullscreen", "vsync"]:
		if typeof(options.get(key)) != TYPE_BOOL:
			return false
	if options.get("window_size") not in SIZES or not options.get("bindings") is Dictionary:
		return false
	var used: Array = []
	for action in DEFAULT_BINDINGS:
		var key: Variant = options.bindings.get(action)
		if typeof(key) != TYPE_INT or key <= 0 or key in used:
			return false
		if key == KEY_ESCAPE and action != "pause":
			return false
		used.append(key)
	return true

func apply_options(options: Dictionary) -> bool:
	if not validate_options(options):
		return false
	values = options.duplicate(true)
	for entry in [["Master", "master_volume"], ["Music", "music_volume"], ["SFX", "sfx_volume"]]:
		var index := AudioServer.get_bus_index(entry[0])
		AudioServer.set_bus_volume_linear(index, values[entry[1]])
	for action in DEFAULT_BINDINGS:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		var key := InputEventKey.new()
		key.physical_keycode = values.bindings[action]
		InputMap.action_add_event(action, key)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not values.fullscreen:
			DisplayServer.window_set_size(values.window_size)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	changed.emit()
	return true

func save_options(path: String = SETTINGS_PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("preferences", "values", values)
	return config.save(path)

func load_options(path: String = SETTINGS_PATH) -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		return error
	var loaded: Variant = config.get_value("preferences", "values", {})
	if not loaded is Dictionary or not apply_options(loaded):
		return ERR_INVALID_DATA
	return OK
