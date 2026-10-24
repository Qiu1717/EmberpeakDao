extends Control
## 安全驻地只读取永久档案；不建立探索、不覆盖可继续的存档。
const Ui := preload("res://scripts/ui/ui_style.gd")
var player: CharacterBody2D
var feedback: Label

func _ready() -> void:
	var app: Node = get_node("/root/App")
	var session: Node = get_node("/root/Session")
	app.enter_playing()
	$BackgroundLayer/Backdrop.hide()
	var room := preload("res://scenes/rooms/sword_entry.tscn").instantiate()
	$World.add_child(room)
	var map: Node2D = room.map
	player = preload("res://scenes/player/player.tscn").instantiate()
	$Actors.add_child(player)
	var stats: Dictionary = session.profile.stats()
	player.stats.max_health = stats.max_health
	player.stats.realm_multiplier = stats.attack_multiplier
	player.stats.qi_max = stats.max_qi
	player.health = stats.max_health
	player.qi = stats.max_qi
	player.reset_motion_at(Vector2(1040, map.floor_at(1040)))
	room.enter(player, false)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_right = 1672
	camera.limit_bottom = 941
	camera.zoom = Vector2(1.35, 1.35)
	var box := VBoxContainer.new()
	box.position = Vector2(40, 36)
	box.custom_minimum_size = Vector2(580, 0)
	box.add_theme_constant_override("separation", 12)
	box.theme = Ui.theme()
	$UI/Overlay.add_child(box)
	Ui.label(box, "问道残庭", 38)
	Ui.label(box, "临时驻地 · 复用剑冢入口地形／建筑待制作", 16)
	Ui.label(box, "%s　已记录灵气%d／灵石%d" % [stats.name, session.profile.banked_spirit, session.profile.banked_stones])
	Ui.label(box, "武器解锁%d种　蓝图%d份　已击败镇山妖将：%s" % [session.profile.weapon_unlocks.size(), session.profile.blueprints.size(), "是" if session.profile.boss_kills.has("mountain_general") else "否"], 16)
	var note := Ui.label(box, "新探索清除上次未记录内容；已有快照可继续。\n剑师、铁匠和采药人在剑冢安全入口提供服务。", 16)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Ui.button(box, "开始新的探索", "HomeNewRun", app.start_new_game, self)
	var resume := Ui.button(box, "继续已保存探索", "HomeContinue", app.continue_game, self)
	resume.disabled = not session.can_continue()
	Ui.button(box, "返回主菜单", "HomeMenu", app.return_to_menu, self)
	feedback = Ui.label(box, session.message, 16)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	session.feedback.connect(_show_feedback)

func _show_feedback(text: String) -> void:
	feedback.text = text
