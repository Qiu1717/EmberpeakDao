extends "res://scripts/world/sword_route.gd"
## 只组织手工房间；战斗沿用原角色、敌人与碰撞实现。
signal interaction_requested(kind: String, payload: Dictionary)
const Graph := preload("res://scripts/roguelite/run_graph.gd")
const Run := preload("res://scripts/roguelite/run_state.gd")
const Ui := preload("res://scripts/ui/ui_style.gd")
const Inventory := preload("res://scripts/inventory/inventory_state.gd")
const Services := preload("res://resources/npcs/first_map_services.tres")
const NpcMarker := preload("res://scripts/npcs/npc_marker.gd")
var services: Resource = Services
var medicine := 2
var graph: RefCounted
var run: RefCounted
var inventory: RefCounted
var session: Node
var resume_data: Dictionary = {}
var growth_queued := false
var death_summary: Dictionary = {}
var current_id := "entry"
var visited: Dictionary = {}
var upgrade_pending: Dictionary = {}
var base_stats: Resource

func _ready() -> void:
	session = get_node("/root/Session")
	resume_data = session.take_resume()
	var random := RandomNumberGenerator.new()
	random.randomize()
	run = Run.new(random.randi())
	inventory = Inventory.new()
	if not resume_data.is_empty():
		run.restore(resume_data.run)
		inventory.restore(resume_data.inventory, session.profile.realm)
		visited = resume_data.visited.duplicate(true)
		cleared_rooms = resume_data.cleared_rooms.duplicate(true)
		upgrade_pending = resume_data.upgrade_pending.duplicate(true)
		medicine = int(resume_data.get("medicine", services.medicine_capacity))
	else:
		for id in session.profile.weapon_unlocks:
			var record := {"instance_id": run.run_id + ":base:" + id, "item_id": id, "name": inventory.catalog.items[id].name}
			inventory.add_item(record)
		inventory.equip(run.run_id + ":base:qing_feng", session.profile.realm)
	graph = Graph.new()
	graph.generate(run.seed)
	super._ready()
	base_stats = player.stats.duplicate(true)
	if not resume_data.is_empty():
		player.health = int(resume_data.health)
		player.qi = float(resume_data.qi)
	_apply_stats(false)
	if resume_data.is_empty():
		player.health = player.stats.max_health
		player.qi = player.stats.qi_max
	run.changed.connect(_on_run_changed)
	run.equipment_dropped.connect(func(record: Dictionary): inventory.add_item(record))
	session.changed.connect(_apply_stats)
	session.feedback.connect(_on_feedback)
	player.died.connect(_on_player_died)
	player.lethal_guard = _use_lethal_guard
	get_node("/root/App").log_event("探索种子", str(run.seed))

func enter_room(_index: int) -> void:
	# 父类初始化只进入入口；后续移动必须通过 travel_to 的连接校验。
	_load_node(str(resume_data.get("current_id", "entry")), false)

func _load_node(id: String, backwards: bool) -> void:
	transitioning = true
	current_id = id
	visited[id] = true
	room_index = graph.nodes.keys().find(id)
	var node: Dictionary = graph.nodes[id]
	var enemies: Dictionary = resume_data.get("enemies", {}) if resume_data.get("current_id") == id else {}
	var armors: Dictionary = resume_data.get("enemy_armor", {}) if resume_data.get("current_id") == id else {}
	_mount_room(load(node.scene_path), backwards, id, node.label, enemies, armors)
	resume_data.erase("enemies")
	resume_data.erase("enemy_armor")
	if node.kind in ["event", "shop", "reward", "altar"]:
		var marker := Label.new()
		marker.name = "InteractionMarker"
		marker.theme = Ui.theme()
		marker.add_theme_color_override("font_color", Ui.GOLD)
		marker.text = {"event": "旧碑 · 按交互键", "shop": "无面商人 · 按交互键\n临时交互标识", "reward": "宝箱 · 按交互键\n临时交互标识", "altar": "灵脉祭坛 · 按交互键休整"}[node.kind]
		marker.position = interaction_point() + Vector2(-130, -125)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		room.add_child(marker)
	for npc_id in npc_ids():
		var npc := Node2D.new()
		npc.set_script(NpcMarker)
		npc.name = "NPC_" + npc_id
		npc.display_name = services.characters[npc_id].name
		npc.position = npc_point(npc_id)
		room.add_child(npc)

func travel_to(id: String) -> bool:
	if transitioning or get_tree().paused or run.ended or player.health <= 0 or not room.is_cleared or upgrade_pending.has(current_id):
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
	if current_id == "entry":
		for npc_id in npc_ids():
			if near_npc(npc_id):
				interaction_requested.emit("npc", {"npc_id": npc_id})
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
				medicine = services.medicine_capacity
				player.health = player.stats.max_health
				player.qi = player.stats.qi_max
				player.health_changed.emit(player.health, player.stats.max_health)
				interaction_requested.emit("altar", {})
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
	var result: Dictionary = session.purchase(self, id)
	_apply_health_result(result)
	return result

func _apply_health_result(result: Dictionary) -> void:
	last_reward = result.message
	if result.accepted:
		player.health = mini(player.stats.max_health, player.health - int(result.get("health_cost", 0)) + int(result.get("health_restored", 0)))
		player.health_changed.emit(player.health, player.stats.max_health)

func _apply_stats(heal_gain: bool = true) -> void:
	var values: Dictionary = run.stat_modifiers()
	var realm: Dictionary = session.profile.stats()
	var equipment: Dictionary = inventory.modifiers()
	var previous_max: int = player.stats.max_health
	var weapon: String = inventory.weapon_id()
	player.apply_weapon(weapon if not weapon.is_empty() else "qing_feng")
	if weapon.is_empty():
		player.apply_weapon("")
	player.stats.max_health = realm.max_health + int(values.health_bonus) + equipment.health_bonus
	player.stats.realm_multiplier = realm.attack_multiplier
	player.stats.defense = base_stats.defense + values.defense_bonus + equipment.defense_bonus
	player.stats.third_attack_multiplier = equipment.third_attack_multiplier
	player.stats.qi_max = realm.max_qi + equipment.qi_bonus
	player.stats.qi_regen = base_stats.qi_regen * equipment.qi_regen_multiplier
	player.qi = minf(player.qi, player.stats.qi_max)
	player.stats.critical_chance = base_stats.critical_chance + values.crit_bonus
	player.stats.dodge_cooldown = base_stats.dodge_cooldown * (1.0 - values.dodge_reduction)
	for index in player.stats.sword_damage.size():
		player.stats.sword_damage[index] *= values.attack_multiplier
	for property in ["attack_windup", "attack_active", "attack_duration"]:
		player.stats.set(property, player.stats.get(property) / (1.0 + values.haste))
	if player.health > 0:
		player.health = mini(player.stats.max_health, player.health + (maxi(0, player.stats.max_health - previous_max) if heal_gain else 0))
	player.health_changed.emit(player.health, player.stats.max_health)

func _on_player_died() -> void:
	var saved_result: Dictionary = session.save_death()
	death_summary = run.finish_run("death")
	inventory.items.clear()
	inventory.equipped.clear()
	_apply_stats(false)
	upgrade_pending.clear()
	last_reward = "本次探索结束：局内内容清除；已保存境界、已记录余额和永久解锁保留。" if saved_result.accepted else session.message
	# 先播放既有倒下动作，再显示总结；清理事务已经同步完成。
	await get_tree().create_timer(0.65, false).timeout
	interaction_requested.emit("death", death_summary)

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
		return "镇山妖将已败；左侧出口可返回原祭坛，记录材料并突破筑基"
	if current_id == "entry":
		return "安全入口：靠近沈砚舟／顾长庚／阿蘅按交互键；右门选择探索路线"
	return "通路已解锁：靠近右门选择前路，左门返回；中央标记可交互"

func _on_run_changed() -> void:
	_apply_stats()
	if not growth_queued:
		growth_queued = true
		_settle_growth.call_deferred()

func _settle_growth() -> void:
	growth_queued = false
	if run.ended:
		return
	var result: Dictionary = session.grow(self)
	if result.has("message") and not result.message.is_empty():
		last_reward = result.message

func _on_feedback(text: String) -> void:
	last_reward = text

func equip_item(instance_id: String) -> Dictionary:
	if run.ended or player.health <= 0:
		return {"accepted": false, "message": "本次探索已结束"}
	var result: Dictionary = inventory.equip(instance_id, session.profile.realm)
	if result.accepted:
		player.reset_motion_at(player.position)
		_apply_stats(false)
	last_reward = result.message
	return result

func unequip(slot: String) -> Dictionary:
	var result: Dictionary = inventory.unequip(slot)
	if result.accepted:
		player.reset_motion_at(player.position)
		_apply_stats(false)
	last_reward = result.message
	return result

func altar_action(action: String, item_id: String = "") -> Dictionary:
	var result: Dictionary = session.altar_action(self, action, item_id)
	last_reward = result.message
	return result

func retry_death() -> void:
	var result: Dictionary = session.save_death()
	last_reward = result.message

func complete_exploration() -> Dictionary:
	var result: Dictionary = session.complete_exploration(self)
	last_reward = result.message
	if result.accepted:
		run.finish_run("victory")
		inventory.items.clear()
		inventory.equipped.clear()
		upgrade_pending.clear()
	return result

func npc_ids() -> Array:
	if current_id == "entry":
		return ["shen_yan_zhou", "gu_chang_geng", "a_heng"]
	if current_id == "altar":
		return ["can_deng"]
	if graph.nodes[current_id].kind == "shop":
		return ["faceless"]
	return []

func npc_point(id: String) -> Vector2:
	var x: float = {"shen_yan_zhou": 380.0, "gu_chang_geng": 700.0, "a_heng": 1120.0}.get(id, 920.0)
	return Vector2(x, room.map.floor_at(x))

func near_npc(id: String) -> bool:
	return id in npc_ids() and player.position.distance_to(npc_point(id)) < 100

func npc_action(id: String, action: String, item_id: String = "") -> Dictionary:
	var result: Dictionary = {"accepted": false, "message": "请靠近对应NPC再操作。"}
	if run.ended or player.health <= 0 or not room.is_cleared or not near_npc(id):
		return result
	if id == "gu_chang_geng" and action == "blueprint":
		result = session.register_blueprint(self, item_id)
	elif id == "a_heng" and action == "supply":
		result = session.supply_medicine(self)
	elif id == "shen_yan_zhou" and action == "practice":
		_create_practice_target()
		result = {"accepted": true, "message": "前方木桩可承受攻击，不提供任何奖励。"}
	last_reward = result.message
	return result

func _create_practice_target() -> void:
	if room.has_node("PracticeTarget"):
		room.get_node("PracticeTarget").health = 200
		return
	var target := CharacterBody2D.new()
	target.set_script(preload("res://scripts/world/training_target.gd"))
	target.name = "PracticeTarget"
	target.collision_layer = 4
	target.collision_mask = 1
	target.position = Vector2(520, room.map.floor_at(520))
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(36, 60)
	shape.position.y = -30
	target.add_child(shape)
	room.add_child(target)

func use_medicine() -> Dictionary:
	if run.ended or get_tree().paused or player.state in [player.State.DEAD, player.State.HURT, player.State.ATTACK, player.State.DODGE] or medicine <= 0 or player.health >= player.stats.max_health:
		return {"accepted": false, "message": "当前不能使用药品，或药品已用尽／生命已满。"}
	medicine -= 1
	player.health = mini(player.stats.max_health, player.health + services.medicine_heal)
	player.health_changed.emit(player.health, player.stats.max_health)
	last_reward = "使用随身药品，恢复最多%d生命，剩余%d次" % [services.medicine_heal, medicine]
	return {"accepted": true, "message": last_reward}

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("heal") and not event.is_echo():
		use_medicine()
		get_viewport().set_input_as_handled()
	else:
		super._unhandled_input(event)

func capture_snapshot(run_override: Dictionary = {}) -> Dictionary:
	var enemy_health: Dictionary = {}
	var enemy_armor: Dictionary = {}
	for enemy in room.enemies:
		if is_instance_valid(enemy):
			enemy_health[str(enemy.source_id)] = enemy.health
			enemy_armor[str(enemy.source_id)] = enemy.armor
	return {"run": run.to_dict() if run_override.is_empty() else run_override.duplicate(true), "inventory": inventory.to_dict(), "current_id": current_id, "visited": visited.duplicate(true), "cleared_rooms": cleared_rooms.duplicate(true), "upgrade_pending": upgrade_pending.duplicate(true), "health": player.health, "qi": player.qi, "medicine": medicine, "enemies": enemy_health, "enemy_armor": enemy_armor}
