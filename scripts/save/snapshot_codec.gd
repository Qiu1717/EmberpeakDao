extends RefCounted
## 完整存档的只读语义校验，不写盘、不激活场景、不发布候选状态。

const Profile := preload("res://scripts/progression/profile_state.gd")
const Run := preload("res://scripts/roguelite/run_state.gd")
const Inventory := preload("res://scripts/inventory/inventory_state.gd")
const Graph := preload("res://scripts/roguelite/run_graph.gd")

static func validate(data: Dictionary) -> bool:
	if not Run.whole(data.get("save_version"), 1, 1) or not Run.whole(data.get("revision"), 1, 9007199254740991):
		return false
	if not data.get("profile") is Dictionary or not data.has("run_snapshot"):
		return false
	var profile := Profile.new()
	if not profile.restore(data.profile):
		return false
	if data.run_snapshot == null:
		return true
	if not data.run_snapshot is Dictionary:
		return false
	return _snapshot(data.run_snapshot, profile)

static func _snapshot(snapshot: Dictionary, profile: RefCounted) -> bool:
	for field in ["run", "inventory", "visited", "cleared_rooms", "upgrade_pending", "enemies"]:
		if not snapshot.get(field) is Dictionary:
			return false
	if not snapshot.get("current_id") is String or not Run.whole(snapshot.get("health"), 1):
		return false
	if not Run.whole(snapshot.get("medicine", 2), 0, 2):
		return false
	var qi: Variant = snapshot.get("qi")
	if not typeof(qi) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(qi)) or qi < 0:
		return false
	var run := Run.new()
	var inventory := Inventory.new()
	if not run.restore(snapshot.run) or run.ended or not inventory.restore(snapshot.inventory, profile.realm):
		return false
	var graph := Graph.new()
	graph.generate(run.seed)
	if not graph.nodes.has(snapshot.current_id):
		return false
	for field in ["visited", "cleared_rooms", "upgrade_pending"]:
		if not _node_flags(snapshot[field], graph.nodes):
			return false
	if not snapshot.visited.has(snapshot.current_id):
		return false
	for field in ["cleared_rooms", "upgrade_pending"]:
		for id in snapshot[field]:
			if not snapshot.visited.has(id):
				return false
	for id in snapshot.upgrade_pending:
		if not snapshot.cleared_rooms.has(id) or not graph.nodes[id].kind in ["combat", "elite", "boss"] or not snapshot.run.offers.has(id) or snapshot.run.chosen.has(id):
			return false
		if snapshot.run.offers[id].is_empty():
			return false
	var stats: Dictionary = profile.stats()
	var equipment: Dictionary = inventory.modifiers()
	if snapshot.health > stats.max_health + equipment.health_bonus + run.stat_modifiers().health_bonus or qi > stats.max_qi + equipment.qi_bonus:
		return false
	if not _inventory_sources(run.equipment_rewards, inventory.items, profile.weapon_unlocks):
		return false
	return _enemies(snapshot, graph.nodes[snapshot.current_id])

static func _node_flags(flags: Dictionary, nodes: Dictionary) -> bool:
	for id: Variant in flags:
		if not id is String or not nodes.has(id) or not flags[id] is bool or not flags[id]:
			return false
	return true

static func _inventory_sources(rewards: Array, items: Array, unlocks: Array) -> bool:
	var held: Dictionary = {}
	var drops: Dictionary = {}
	for record: Dictionary in items:
		held[record.instance_id] = record
	for reward: Dictionary in rewards:
		if not held.has(reward.instance_id) or held[reward.instance_id] != reward:
			return false
		drops[reward.instance_id] = true
	for record: Dictionary in items:
		if not drops.has(record.instance_id) and not unlocks.has(record.item_id):
			return false
	return true

static func _enemies(snapshot: Dictionary, node: Dictionary) -> bool:
	var armors: Variant = snapshot.get("enemy_armor", {})
	if not armors is Dictionary:
		return false
	var packed: PackedScene = load(node.scene_path)
	var room: Node = packed.instantiate()
	var limits: Dictionary = {}
	var armor_limits: Dictionary = {}
	for index in room.enemy_data.size():
		var source := "%s:%s" % [snapshot.current_id, index]
		limits[source] = room.enemy_data[index].max_health
		armor_limits[source] = room.enemy_data[index].armor_points
	room.free()
	for source: Variant in armors:
		if not source is String or not armor_limits.has(source):
			return false
		var armor: Variant = armors[source]
		if not typeof(armor) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(armor)) or armor < 0 or armor > armor_limits[source]:
			return false
	var cleared: bool = snapshot.cleared_rooms.has(snapshot.current_id)
	if not cleared and snapshot.enemies.size() != limits.size():
		return false
	for source: Variant in snapshot.enemies:
		if not source is String or not limits.has(source) or not Run.whole(snapshot.enemies[source], 0, limits[source]):
			return false
		var health: int = int(snapshot.enemies[source])
		if (cleared and health > 0) or (health == 0 and not snapshot.run.claimed.has("enemy:" + source)):
			return false
	return true
