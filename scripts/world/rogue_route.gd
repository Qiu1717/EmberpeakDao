extends "res://scripts/world/sword_route.gd"
## 只组织手工房间；战斗沿用原角色、敌人与碰撞实现。
signal interaction_requested(kind: String, payload: Dictionary)
const Graph := preload("res://scripts/roguelite/run_graph.gd")
const Run := preload("res://scripts/roguelite/run_state.gd")
const Ui := preload("res://scripts/ui/ui_style.gd")
var graph: RefCounted
var run: RefCounted
var current_id := "entry"
var visited: Dictionary = {}
var upgrade_pending: Dictionary = {}
var base_stats: Resource

func _ready() -> void:
	var random := RandomNumberGenerator.new()
	random.randomize()
	run = Run.new(random.randi())
	graph = Graph.new()
	graph.generate(run.seed)
	super._ready()
	base_stats = player.stats.duplicate(true)
	run.changed.connect(_apply_stats)
	player.died.connect(_on_player_died)
	player.lethal_guard = _use_lethal_guard
	get_node("/root/App").log_event("探索种子", str(run.seed))

func enter_room(_index: int) -> void:
	# 父类初始化只进入入口；后续移动必须通过 travel_to 的连接校验。
	_load_node("entry", false)

func _load_node(id: String, backwards: bool) -> void:
	transitioning = true
	current_id = id
	visited[id] = true
	room_index = graph.nodes.keys().find(id)
	var node: Dictionary = graph.nodes[id]
	_mount_room(load(node.scene_path), backwards, id, node.label)
	if node.kind in ["event", "shop", "reward", "altar"]:
		var marker := Label.new()
		marker.name = "InteractionMarker"
		marker.theme = Ui.theme()
		marker.add_theme_color_override("font_color", Ui.GOLD)
		marker.text = {"event": "旧碑 · 按交互键", "shop": "无面商人 · 按交互键\n临时交互标识", "reward": "宝箱 · 按交互键\n临时交互标识", "altar": "灵脉祭坛 · 按交互键休整"}[node.kind]
		marker.position = interaction_point() + Vector2(-130, -125)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		room.add_child(marker)

func travel_to(id: String) -> bool:
	if transitioning or run.ended or player.health <= 0 or not room.is_cleared or upgrade_pending.has(current_id):
		return false
	var node: Dictionary = graph.nodes[current_id]
	var backwards: bool = id in node.previous and visited.has(id)
	if not id in node.next and not backwards:
		return false
	_load_node(id, backwards)
	return true

func route_choices(backwards: bool = false) -> Array:
	var result: Array = []
	var node: Dictionary = graph.nodes[current_id]
	for id in node.previous if backwards else node.next:
		if not backwards or visited.has(id):
			result.append(graph.nodes[id])
	return result

func _on_room_cleared(id: String) -> void:
	var first := not cleared_rooms.has(id)
	super._on_room_cleared(id)
	if first and graph.nodes[id].kind in ["combat", "elite", "boss"] and not run.ended:
		if not run.offer_upgrades(id).is_empty():
			upgrade_pending[id] = true
			request_upgrade.call_deferred()

func request_upgrade() -> void:
	if run.ended or not upgrade_pending.has(current_id):
		return
	interaction_requested.emit("upgrade", {"options": run.offer_upgrades(current_id)})

func choose_upgrade(id: String) -> bool:
	if not upgrade_pending.has(current_id) or not run.choose_upgrade(current_id, id):
		return false
	upgrade_pending.erase(current_id)
	last_reward = "获得局内强化：" + run.rules.upgrades[id].name
	return true

func _on_reward(payload: Dictionary) -> void:
	var result: Dictionary = run.claim_enemy(str(payload.source_id), str(payload.enemy_id))
	if result.accepted:
		last_reward = result.message
		reward_requested.emit(result)

func interaction_point() -> Vector2:
	return room.altar_point if current_id == "altar" else Vector2(920, room.map.floor_at(920))

func interact() -> void:
	if transitioning or run.ended or player.health <= 0 or not room.is_cleared:
		return
	if upgrade_pending.has(current_id):
		request_upgrade()
		return
	var kind: String = graph.nodes[current_id].kind
	if player.position.distance_to(interaction_point()) < 120:
		match kind:
			"event":
				if run.is_event_completed(current_id):
					last_reward = "旧碑奇遇已完成；本次探索不能再次选择或领取奖励"
					return
				interaction_requested.emit("event", {"event_id": "sword_question"})
				return
			"shop":
				interaction_requested.emit("shop", {})
				return
			"reward":
				var result: Dictionary = run.claim_chest(current_id)
				last_reward = result.message
				return
			"altar":
				player.health = player.stats.max_health
				player.health_changed.emit(player.health, player.stats.max_health)
				last_reward = "生命已恢复；资源记录和境界突破待后续阶段接入"
				return
	if player.position.distance_to(room.exit_point) < 110:
		interaction_requested.emit("route", {"choices": route_choices()})
	elif player.position.distance_to(room.entry_point) < 110:
		interaction_requested.emit("route", {"choices": route_choices(true)})

func resolve_event(choice: String) -> Dictionary:
	if graph.nodes[current_id].kind != "event" or not room.is_cleared:
		return {"accepted": false, "message": "当前没有可选择的奇遇"}
	var result: Dictionary = run.resolve_event(current_id, "sword_question", choice, player.health, player.stats.max_health)
	_apply_health_result(result)
	return result

func buy(id: String) -> Dictionary:
	if graph.nodes[current_id].kind != "shop":
		return {"accepted": false, "message": "当前不在商店"}
	var result: Dictionary = run.buy(current_id, id, player.health, player.stats.max_health)
	_apply_health_result(result)
	return result

func _apply_health_result(result: Dictionary) -> void:
	last_reward = result.message
	if result.accepted:
		player.health = mini(player.stats.max_health, player.health - int(result.get("health_cost", 0)) + int(result.get("health_restored", 0)))
		player.health_changed.emit(player.health, player.stats.max_health)

func _apply_stats() -> void:
	var values: Dictionary = run.stat_modifiers()
	var previous_max: int = player.stats.max_health
	player.stats.max_health = base_stats.max_health + int(values.health_bonus)
	player.stats.defense = base_stats.defense + values.defense_bonus
	player.stats.critical_chance = base_stats.critical_chance + values.crit_bonus
	player.stats.dodge_cooldown = base_stats.dodge_cooldown * (1.0 - values.dodge_reduction)
	player.stats.sword_damage = base_stats.sword_damage.duplicate()
	for index in player.stats.sword_damage.size():
		player.stats.sword_damage[index] *= values.attack_multiplier
	for property in ["attack_windup", "attack_active", "attack_duration"]:
		player.stats.set(property, base_stats.get(property) / (1.0 + values.haste))
	if player.health > 0:
		player.health = mini(player.stats.max_health, player.health + maxi(0, player.stats.max_health - previous_max))
	player.health_changed.emit(player.health, player.stats.max_health)

func _on_player_died() -> void:
	var summary: Dictionary = run.finish_run("death")
	upgrade_pending.clear()
	last_reward = "本次探索结束：局内强化和未记录的灵气、灵石、材料、装备已清除"
	# 先播放既有倒下动作，再显示总结；清理事务已经同步完成。
	await get_tree().create_timer(0.65, false).timeout
	interaction_requested.emit("death", summary)

func _use_lethal_guard() -> bool:
	if not run.use_lethal_guard():
		return false
	last_reward = "替劫符已消耗，抵挡本次致死伤害，保留1点生命"
	return true

func status_text() -> String:
	if run.ended:
		return "已倒下，请重新开始探索"
	if upgrade_pending.has(current_id):
		return "首次清场奖励待选择：按交互键继续三选一"
	if not room.is_cleared:
		return "战斗中：剩余 %d，清场后解锁出口" % room.alive
	if current_id == "boss":
		return "镇山妖将已败；左侧出口可返回原祭坛。装备穿戴与永久记录待接入"
	return "通路已解锁：靠近右门选择前路，左门返回；中央标记可交互"
