extends Node2D
## 复用真实战斗的单房美术候选；主角静态侧视，背景为未拆层概念图。
const Player := preload("res://scenes/player/player.tscn")
const Room := preload("res://scripts/world/combat_room.gd")
const Stats := preload("res://resources/enemies/shan_xiao.tres")
const Ui := preload("res://scripts/ui/ui_style.gd")
var player: CharacterBody2D
var enemy: CharacterBody2D
var arena: Room
var status: Label
@onready var app: Node = get_node("/root/App")

func _ready() -> void:
	# F6直接运行同样支持暂停，不要求先经过主菜单。
	if app.state == app.State.BOOT:
		app.enter_playing()
	arena = Room.new()
	arena.name = "ArtArena"
	arena.room_id = "shan_xiao_art"
	arena.display_name = "山魈美术样板"
	arena.platforms = [Rect2(850, 540, 220, 24), Rect2(1200, 450, 180, 24)]
	arena.enemy_data = [Stats]
	arena.enemy_positions = PackedVector2Array([Vector2(700, 640)])
	add_child(arena)
	player = Player.instantiate()
	player.name = "Player"
	player.position = Vector2(310, 640)
	arena.add_child(player)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.zoom = Vector2(1.5, 1.5)
	camera.position.y = -160
	camera.reset_smoothing()
	arena.enter(player, false)
	enemy = arena.enemies[0]
	_build_ui()

func _build_ui() -> void:
	var panel := VBoxContainer.new()
	panel.position = Vector2(28, 24)
	panel.add_theme_constant_override("separation", 8)
	panel.theme = Ui.theme()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(panel)
	Ui.label(panel, "无名剑冢 · 山魈美术样板", 30).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.label(panel, "山魈动作候选｜主角静态侧视图｜背景概念图，建筑待匹配 · 1.5倍镜头", 16).mouse_filter = Control.MOUSE_FILTER_IGNORE
	status = Ui.label(panel, "", 18)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tools := HBoxContainer.new()
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools.add_theme_constant_override("separation", 12)
	panel.add_child(tools)
	Ui.button(tools, "重新挑战", "RestartArt", restart_room, self)
	Ui.button(tools, "暂停", "PauseArt", func(): app.set_paused(true), self)
	Ui.button(tools, "返回主菜单", "MenuArt", app.return_to_menu, self)
	var bounds := CheckBox.new()
	bounds.text = "显示身体碰撞"
	bounds.toggled.connect(func(value: bool):
		if is_instance_valid(enemy):
			enemy.get_node("Visual").show_body_bounds = value
	)
	tools.add_child(bounds)
	for button in tools.get_children():
		button.focus_mode = Control.FOCUS_NONE
	Ui.label(panel, "A/D移动 · Space跳跃 · J/左键攻击 · Shift闪避 · Esc暂停（可在设置重绑）", 15).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.label(panel, "观察白鬃剪影、脚底、扑击前摇和落地收招；击败后可重新挑战。", 15).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	var text := "玩家生命 %d / %d" % [player.health, player.stats.max_health]
	if is_instance_valid(enemy):
		var states := ["休眠", "现身", "待机", "巡逻", "发现", "追击", "蓄力预警", "扑击", "收招：反击机会", "返回", "受击", "转阶段", "倒下"]
		text += "　山魈生命 %d / %d　%s" % [enemy.health, enemy.data.max_health, states[enemy.state]]
	else:
		text += "　山魈已击败，可以重新挑战"
	if player.health <= 0:
		text += "　您已倒下，请重新挑战"
	status.text = text

func restart_room() -> void:
	app.start_art_room()
