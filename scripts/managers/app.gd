extends Node
## 仅管理应用生命周期；局内成长、战斗与永久档案由后续模块接入。

signal state_changed(state: int)
signal session_started
signal scene_changed(path: String)

enum State { BOOT, MENU, PLAYING, PAUSED }
const MENU_SCENE := "res://scenes/main/main_menu.tscn"
const GAME_SCENE := "res://scenes/world/game.tscn"
var state: State = State.BOOT
var transitioning := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	log_event("初始化", "应用服务已就绪")

func log_event(category: String, message: String) -> void:
	print("[%s][%s] %s" % [Time.get_time_string_from_system(), category, message])

func enter_menu() -> void:
	_set_state(State.MENU)

func start_new_game() -> void:
	if await _switch_scene(GAME_SCENE, State.PLAYING):
		session_started.emit()

func return_to_menu() -> void:
	await _switch_scene(MENU_SCENE, State.MENU)

func _switch_scene(path: String, next_state: State) -> bool:
	if transitioning:
		return false
	transitioning = true
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		transitioning = false
		push_error("场景加载失败：%s，错误 %s" % [path, error_string(error)])
		return false
	get_tree().paused = false
	_set_state(next_state)
	await get_tree().scene_changed
	transitioning = false
	log_event("场景", path)
	scene_changed.emit(path)
	return true

func set_paused(value: bool) -> void:
	if transitioning or state not in [State.PLAYING, State.PAUSED]:
		return
	get_tree().paused = value
	_set_state(State.PAUSED if value else State.PLAYING)
	log_event("暂停", "暂停" if value else "恢复")

func _set_state(value: State) -> void:
	state = value
	state_changed.emit(state)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo() and state in [State.PLAYING, State.PAUSED]:
		set_paused(state == State.PLAYING)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func quit_game() -> void:
	log_event("退出", "正常结束应用")
	get_tree().paused = false
	get_tree().quit()
