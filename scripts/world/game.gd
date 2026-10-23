extends Control
@onready var app: Node = get_node("/root/App")

const Ui := preload("res://scripts/ui/ui_style.gd")
@export var training_mode := false
const Route := preload("res://scripts/world/sword_route.gd")
const Arena := preload("res://scripts/world/training_arena.gd")
var player: CharacterBody2D
var health_bar: ProgressBar
var combat_status: Label
var room_title: Label
var route_status: Label
var enemy_status: Label
var world: Node
var concept: TextureRect
var concept_name: Label

func _ready() -> void:
	var arena := Node2D.new()
	arena.name = "TrainingArena" if training_mode else "SwordRoute"
	arena.set_script(Arena if training_mode else Route)
	$World.add_child(arena)
	world = arena
	if not training_mode:
		$BackgroundLayer/Backdrop.hide()
	player = arena.get_node("Player") if training_mode else arena.player
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
	room_title = Ui.label(top, "剑术训练场" if training_mode else world.room.display_name, 30)
	room_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pause_button := Ui.button(top, "暂停", "Pause", func(): app.set_paused(true), self)
	app.state_changed.connect(func(state: int): pause_button.disabled = state == app.State.PAUSED)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(320, 24)
	health_bar.max_value = player.stats.max_health
	health_bar.value = player.health
	layout.add_child(health_bar)
	combat_status = Ui.label(layout, "", 16)
	enemy_status = Ui.label(layout, "", 16)
	var tools := HBoxContainer.new()
	layout.add_child(tools)
	var actions: Array = [["重新训练" if training_mode else "重新开始路线", "Restart", app.start_training if training_mode else app.start_new_game]]
	if training_mode:
		actions.push_front(["致死测试", "TestDeath", func(): player.receive_hit(1000, Vector2.ZERO)])
		actions.push_front(["受击测试 −10", "TestHit", func(): player.receive_hit(10, Vector2(-180, -100))])
	for entry in actions:
		var button := Ui.button(tools, entry[0], entry[1], entry[2], self)
		button.focus_mode = Control.FOCUS_NONE
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Ui.label(layout, "基础动作帧候选 · 补帧与美术待精修" + ("｜木桩无敌人 AI" if training_mode else "｜原图关卡 · 断阶需要跳跃"), 16)
	Ui.label(layout, "移动／跳跃／攻击／闪避使用设置中的按键；暂停键打开菜单。", 16)
	route_status = Ui.label(layout, "", 16)
	route_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not training_mode:
		var card := VBoxContainer.new()
		card.position = Vector2(960, 260)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(card)
		concept_name = Ui.label(card, "静态概念图参考，非动画", 14)
		concept = TextureRect.new()
		concept.custom_minimum_size = Vector2(260, 195)
		concept.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		concept.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		concept.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(concept)
		var toggle := Ui.button(tools, "敌人资料卡", "Concept", func(): card.visible = not card.visible, self)
		toggle.focus_mode = Control.FOCUS_NONE
		card.visible = false
	layout.add_child(space)
	# HUD 空白放行世界攻击，按钮仍消费点击。
	for control in [margin, layout, top, tools, space, health_bar]:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.log_event("训练场" if training_mode else "固定路线", "主角与碰撞环境已就绪")

func _process(_delta: float) -> void:
	health_bar.value = player.health
	var states := ["待机", "移动", "空中", "攻击", "闪避", "受击", "死亡"]
	combat_status.text = "生命 %d / %d　%s　闪避冷却 %.2f 秒%s" % [player.health, player.stats.max_health, states[player.state], player.dodge_remaining, ("　已倒下，请重新训练" if training_mode else "　已倒下，请重新开始路线") if player.health == 0 else ""]
	if not training_mode:
		room_title.text = "%s　%d / 6" % [world.room.display_name, world.room_index + 1]
		route_status.text = world.status_text()
		if not world.last_reward.is_empty():
			route_status.text += "\n" + world.last_reward
		var nearest: Node = null
		for enemy in world.room.enemies:
			if is_instance_valid(enemy) and enemy.health > 0 and (nearest == null or enemy.position.distance_to(player.position) < nearest.position.distance_to(player.position)):
				nearest = enemy
		enemy_status.text = ""
		if nearest != null:
			var enemy_states := ["休眠", "现身", "待机", "巡逻", "发现", "接近", "攻击预警", "攻击", "收招：反击机会", "返回", "受击", "转阶段", "死亡"]
			enemy_status.text = "%s　生命%d/%d　第%d阶段　%s%s" % [nearest.data.display_name, nearest.health, nearest.data.max_health, nearest.phase, enemy_states[nearest.state], " · " + nearest.attack.display_name if nearest.attack != null else ""]
			concept.texture = nearest.data.concept_texture
			concept_name.text = nearest.data.display_name + " · 静态概念图，非动画"
		else:
			concept.texture = null
			concept_name.text = "当前房间无存活敌人"
