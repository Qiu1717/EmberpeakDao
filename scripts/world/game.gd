extends Control
@onready var app: Node = get_node("/root/App")

const Ui := preload("res://scripts/ui/ui_style.gd")
const Arena := preload("res://scripts/world/training_arena.gd")
var player: CharacterBody2D
var health_bar: ProgressBar
var combat_status: Label

func _ready() -> void:
	var arena := Node2D.new()
	arena.name = "TrainingArena"
	arena.set_script(Arena)
	$World.add_child(arena)
	player = arena.get_node("Player")
	var overlay := $UI/Overlay
	overlay.theme = Ui.theme()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	overlay.add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var top := HBoxContainer.new()
	layout.add_child(top)
	var title := Ui.label(top, "剑术训练场", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pause_button := Ui.button(top, "暂停", "Pause", func(): app.set_paused(true), self)
	app.state_changed.connect(func(state: int): pause_button.disabled = state == app.State.PAUSED)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(320, 24)
	health_bar.max_value = player.stats.max_health
	health_bar.value = player.health
	layout.add_child(health_bar)
	combat_status = Ui.label(layout, "", 16)
	var tools := HBoxContainer.new()
	layout.add_child(tools)
	for entry in [["受击测试 −10", "TestHit", func(): player.receive_hit(10, Vector2(-180, -100))],
		["致死测试", "TestDeath", func(): player.receive_hit(1000, Vector2.ZERO)],
		["重新训练", "Restart", app.start_new_game]]:
		var button := Ui.button(tools, entry[0], entry[1], entry[2], self)
		button.focus_mode = Control.FOCUS_NONE
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Ui.label(layout, "临时几何角色 · 非正式角色动画｜木桩无敌人 AI", 16)
	Ui.label(layout, "移动／跳跃／攻击／闪避使用设置中的按键；暂停键打开菜单。", 16)
	layout.add_child(space)
	# HUD 空白放行世界攻击，按钮仍消费点击。
	for control in [margin, layout, top, tools, space, health_bar]:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.log_event("训练场", "主角与碰撞训练环境已就绪")

func _process(_delta: float) -> void:
	health_bar.value = player.health
	var states := ["待机", "移动", "空中", "攻击", "闪避", "受击", "死亡"]
	combat_status.text = "生命 %d / %d　%s　闪避冷却 %.2f 秒%s" % [player.health, player.stats.max_health, states[player.state], player.dodge_remaining, "　已倒下，请重新训练" if player.health == 0 else ""]
