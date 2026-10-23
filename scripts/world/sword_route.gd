extends Node2D
signal room_changed
signal reward_requested(payload: Dictionary)
const Player := preload("res://scenes/player/player.tscn")
const Rooms := [preload("res://scenes/rooms/sword_entry.tscn"), preload("res://scenes/rooms/broken_swords.tscn"), preload("res://scenes/rooms/stepped_corridor.tscn"), preload("res://scenes/rooms/elite_den.tscn"), preload("res://scenes/rooms/spirit_altar.tscn"), preload("res://scenes/rooms/general_hall.tscn")]
var room_index := -1
var room: Node2D
var player: CharacterBody2D
var cleared_rooms: Dictionary = {}
var rewards: Dictionary = {}
var last_reward := ""
var transitioning := false

func _ready() -> void:
	player = Player.instantiate()
	get_parent().get_parent().get_node("Actors").add_child(player)
	enter_room(0)

func enter_room(index: int) -> void:
	if transitioning or index < 0 or index >= Rooms.size():
		return
	transitioning = true
	var backwards := index < room_index
	if is_instance_valid(room):
		remove_child(room)
		room.queue_free()
	room_index = index
	room = Rooms[index].instantiate()
	add_child(room)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_right = 1672
	camera.limit_bottom = 941
	camera.zoom = Vector2(1.35, 1.35)
	player.reset_motion_at(room.exit_point if backwards else room.entry_point)
	room.cleared.connect(func(id: String): cleared_rooms[id] = true)
	room.reward_requested.connect(_on_reward)
	room.enter(player, cleared_rooms.has(room.room_id))
	get_node("/root/App").log_event("房间", room.display_name)
	transitioning = false
	room_changed.emit()

func _on_reward(payload: Dictionary) -> void:
	if rewards.has(payload.source_id):
		return
	rewards[payload.source_id] = payload
	last_reward = "镇山妖将已败：筑基灵髓事件已发出，奖励系统尚未接入" if payload.enemy_id == "mountain_general" else "击杀事件已记录；灵气、灵石与装备数量尚未配置"
	reward_requested.emit(payload)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		interact.call_deferred()
		get_viewport().set_input_as_handled()

func interact() -> void:
	if transitioning or player.health <= 0 or not room.is_cleared :
		return
	if room.room_id == "altar" and player.position.distance_to(room.altar_point) < 120:
		player.health = player.stats.max_health
		player.health_changed.emit(player.health, player.stats.max_health)
	elif player.position.distance_to(room.exit_point) < 110 and room_index < Rooms.size() - 1:
		enter_room(room_index + 1)
	elif player.position.distance_to(room.entry_point) < 110 and room_index > 0:
		enter_room(room_index - 1)

func status_text() -> String:
	if player.health <= 0:
		return "已倒下，请重新开始路线；正式资源保留与存档尚未接入"
	var message := "战斗中：剩余%d，清场后解锁通路" % room.alive
	if room.is_cleared:
		message = "通路已解锁：靠近右侧门按交互键前进，左侧门可返回"
	if room_index == 5 and room.is_cleared:
		message = "镇山妖将已败，靠近左门按交互键返回原祭坛"
	if room.room_id == "altar":
		message += "｜中央祭坛按交互键休整，仅恢复生命，无存档／突破"
	return message
