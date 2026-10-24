extends RefCounted

signal changed
signal reward_granted(payload: Dictionary)
signal equipment_dropped(record: Dictionary)

var seed: int
var run_id: String
var spirit := 0
var stones := 0
var materials: Dictionary = {}
var equipment_rewards: Array = []
var upgrades: Dictionary = {}
var ended := false
var rules: Resource
var _drop_rng := RandomNumberGenerator.new()
var _upgrade_rng := RandomNumberGenerator.new()
var _claimed: Dictionary = {}
var _offers: Dictionary = {}
var _chosen: Dictionary = {}
var _shops: Dictionary = {}
var _lethal_guards := 0
var _equipment_serial := 0

func _init(seed_value: int = 0, rules_data: Resource = null) -> void:
	seed = seed_value
	run_id = "%s:%s:%s" % [seed, Time.get_ticks_usec(), get_instance_id()]
	rules = rules_data if rules_data != null else load("res://resources/roguelite/nameless_tomb_rules.tres")
	_drop_rng.seed = seed ^ 0x4D52
	_upgrade_rng.seed = seed ^ 0x915A

func claim_enemy(source_id: String, enemy_id: String) -> Dictionary:
	if not _available("enemy", source_id) or not rules.enemies.has(enemy_id):
		return _reject("该敌人奖励不可领取")
	_claimed["enemy:" + source_id] = true
	return _grant(source_id, "enemy", rules.enemies[enemy_id])

func claim_chest(source_id: String) -> Dictionary:
	if not _available("chest", source_id):
		return _reject("该宝箱已经领取或探索已结束")
	_claimed["chest:" + source_id] = true
	return _grant(source_id, "chest", rules.chest)

func offer_upgrades(source_id: String) -> Array:
	if ended or source_id.is_empty() or _chosen.has(source_id):
		return []
	if _offers.has(source_id):
		return _offers[source_id].duplicate()
	var pool: Array = []
	for id: String in rules.upgrades:
		if float(rules.upgrades[id].weight) > 0.0 and _can_upgrade(id):
			pool.append(id)
	var options: Array = []
	while options.size() < 3 and not pool.is_empty():
		var total := 0.0
		for id: String in pool:
			total += float(rules.upgrades[id].weight)
		var roll := _upgrade_rng.randf() * total
		var selected: String = pool.back()
		for id: String in pool:
			roll -= float(rules.upgrades[id].weight)
			if roll < 0.0:
				selected = id
				break
		options.append(selected)
		pool.erase(selected)
	_offers[source_id] = options
	return options.duplicate()

func choose_upgrade(source_id: String, upgrade_id: String) -> bool:
	if ended or _chosen.has(source_id) or not _offers.get(source_id, []).has(upgrade_id) or not _can_upgrade(upgrade_id):
		return false
	_chosen[source_id] = true
	_add_upgrade(upgrade_id)
	changed.emit()
	return true

func resolve_event(source_id: String, event_id: String, choice_id: String, current_hp: int, max_hp: int) -> Dictionary:
	if not _available("event", source_id) or not rules.events.has(event_id) or current_hp <= 0 or max_hp <= 0:
		return _reject("该奇遇不可使用")
	var choices: Dictionary = rules.events[event_id].choices
	if not choices.has(choice_id):
		return _reject("请选择有效选项")
	var choice: Dictionary = choices[choice_id]
	var failure := _effect_failure(choice, current_hp, max_hp)
	if not failure.is_empty():
		return _reject(failure)
	_claimed["event:" + source_id] = true
	var health_cost := floori(current_hp * float(choice.get("health_fraction", 0.0)))
	var health_restored := mini(int(choice.get("heal", 0)), maxi(0, max_hp - current_hp))
	if choice.has("upgrade"):
		_add_upgrade(choice.upgrade)
	return _grant(source_id, "event", choice, {"health_cost": health_cost, "health_restored": health_restored, "message": "%s：%s" % [rules.events[event_id].name, choice.name]})

func is_event_completed(source_id: String) -> bool:
	return _claimed.has("event:" + source_id)

func shop_inventory(source_id: String) -> Array:
	if ended or source_id.is_empty():
		return []
	if not _shops.has(source_id):
		_shops[source_id] = {}
		for id: String in rules.goods:
			_shops[source_id][id] = int(rules.goods[id].stock)
	var result: Array = []
	for id: String in rules.goods:
		var good: Dictionary = rules.goods[id]
		result.append({"id": id, "name": good.name, "description": good.description, "price": good.price, "remaining": _shops[source_id][id]})
	return result

func buy(source_id: String, good_id: String, current_hp: int, max_hp: int) -> Dictionary:
	if ended or source_id.is_empty() or not rules.goods.has(good_id) or current_hp <= 0 or max_hp <= 0:
		return _reject("无法购买该商品")
	shop_inventory(source_id)
	var good: Dictionary = rules.goods[good_id]
	if int(_shops[source_id][good_id]) <= 0:
		return _reject("商品已售罄")
	if stones < int(good.price):
		return _reject("灵石不足")
	var failure := _effect_failure(good, current_hp, max_hp)
	if not failure.is_empty():
		return _reject(failure)
	stones -= int(good.price)
	_shops[source_id][good_id] -= 1
	if good.has("upgrade"):
		_add_upgrade(good.upgrade)
	_lethal_guards += int(good.get("lethal_guard", 0))
	var result := {"accepted": true, "message": "购得%s" % good.name, "health_cost": 0, "health_restored": mini(int(good.get("heal", 0)), maxi(0, max_hp - current_hp))}
	changed.emit()
	return result

func stat_modifiers() -> Dictionary:
	var result := {"attack_multiplier": 1.0, "health_bonus": 0, "defense_bonus": 0, "crit_bonus": 0.0, "dodge_reduction": 0.0, "haste": 0.0}
	for id: String in upgrades:
		var upgrade: Dictionary = rules.upgrades[id]
		result[upgrade.stat] += upgrade.amount * int(upgrades[id])
	return result

func use_lethal_guard() -> bool:
	if ended or _lethal_guards <= 0:
		return false
	_lethal_guards -= 1
	changed.emit()
	return true

func finish_run(reason: String) -> Dictionary:
	if ended:
		return _reject("探索已经结束")
	var summary := {"accepted": true, "message": "探索结束", "reason": reason, "run_id": run_id, "seed": seed, "spirit": spirit, "stones": stones, "materials": materials.duplicate(true), "equipment_rewards": equipment_rewards.duplicate(true), "upgrades": upgrades.duplicate(true)}
	ended = true
	spirit = 0
	stones = 0
	materials.clear()
	equipment_rewards.clear()
	upgrades.clear()
	_claimed.clear()
	_offers.clear()
	_chosen.clear()
	_shops.clear()
	_lethal_guards = 0
	changed.emit()
	return summary

func _available(kind: String, source_id: String) -> bool:
	return not ended and not source_id.is_empty() and not _claimed.has(kind + ":" + source_id)

func _can_upgrade(id: String) -> bool:
	return rules.upgrades.has(id) and int(upgrades.get(id, 0)) < int(rules.upgrades[id].cap)

func _add_upgrade(id: String) -> void:
	upgrades[id] = int(upgrades.get(id, 0)) + 1

func _effect_failure(effect: Dictionary, current_hp: int, max_hp: int) -> String:
	if effect.has("heal") and current_hp >= max_hp:
		return "生命已满，可选择其他选项"
	if effect.has("upgrade") and not _can_upgrade(effect.upgrade):
		return "该强化已达到叠加上限"
	if effect.has("lethal_guard") and _lethal_guards > 0:
		return "已有一张未消耗的替劫符"
	return ""

func _reject(message: String) -> Dictionary:
	return {"accepted": false, "message": message, "health_cost": 0, "health_restored": 0}

func _grant(source_id: String, kind: String, data: Dictionary, event_details: Dictionary = {}) -> Dictionary:
	var gained_spirit := int(data.get("spirit", 0))
	var gained_stones := int(data.get("stones", 0))
	var gained_materials: Dictionary = {}
	var gained_equipment: Array = []
	if data.has("materials") and _roll(float(data.get("material_chance", 1.0))):
		gained_materials = data.materials.duplicate(true)
		for id: String in gained_materials:
			materials[id] = int(materials.get(id, 0)) + int(gained_materials[id])
	if data.has("equipment_pool") and not data.equipment_pool.is_empty() and _roll(float(data.get("equipment_chance", 0.0))):
		var pool: Array = data.equipment_pool
		var id: String = pool[_drop_rng.randi_range(0, pool.size() - 1)]
		_equipment_serial += 1
		var record := {"instance_id": "%s:equipment:%s" % [run_id, _equipment_serial], "item_id": id, "name": rules.equipment[id].name}
		equipment_rewards.append(record)
		gained_equipment.append(record.duplicate(true))
	spirit += gained_spirit
	stones += gained_stones
	var result := {"accepted": true, "message": "获得灵气%d、灵石%d" % [gained_spirit, gained_stones], "run_id": run_id, "source_id": source_id, "kind": kind, "spirit": gained_spirit, "stones": gained_stones, "materials": gained_materials, "equipment": gained_equipment, "health_cost": 0, "health_restored": 0}
	result.merge(event_details, true)
	for id: String in gained_materials:
		result.message += "；%s × %d" % [rules.material_names[id], gained_materials[id]]
	for record: Dictionary in gained_equipment:
		result.message += "；%s（装备掉落）" % record.name
	for record: Dictionary in gained_equipment:
		equipment_dropped.emit(record.duplicate(true))
	reward_granted.emit(result.duplicate(true))
	changed.emit()
	return result

func _roll(chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return _drop_rng.randf() < chance

func to_dict() -> Dictionary:
	return {"seed": str(seed), "run_id": run_id, "spirit": spirit, "stones": stones, "materials": materials.duplicate(true), "equipment_rewards": equipment_rewards.duplicate(true), "upgrades": upgrades.duplicate(true), "ended": ended, "drop_rng_state": str(_drop_rng.state), "upgrade_rng_state": str(_upgrade_rng.state), "claimed": _claimed.duplicate(true), "offers": _offers.duplicate(true), "chosen": _chosen.duplicate(true), "shops": _shops.duplicate(true), "lethal_guards": _lethal_guards, "equipment_serial": _equipment_serial}

static func whole(value: Variant, minimum: int = 0, maximum: int = 2147483647) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _integer_string(value: Variant) -> bool:
	if not value is String or not value.is_valid_int():
		return false
	var digits: String = value.trim_prefix("-")
	var limit := "9223372036854775808" if value.begins_with("-") else "9223372036854775807"
	if digits.length() > 19 or (digits.length() == 19 and digits > limit):
		return false
	return str(int(value)) == value

static func _flags(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for id in value:
		if not id is String or id.is_empty() or not value[id] is bool or not value[id]:
			return false
	return true

func restore(data: Dictionary) -> bool:
	# 所有校验先完成，损坏快照不能部分污染当前探索。
	for field in ["seed", "run_id", "spirit", "stones", "materials", "equipment_rewards", "upgrades", "ended", "drop_rng_state", "upgrade_rng_state", "claimed", "offers", "chosen", "shops", "lethal_guards", "equipment_serial"]:
		if not data.has(field):
			return false
	if not _integer_string(data.seed) or int(data.seed) < 0 or not _integer_string(data.drop_rng_state) or not _integer_string(data.upgrade_rng_state):
		return false
	if not data.run_id is String or data.run_id.is_empty() or not data.ended is bool:
		return false
	for field in ["spirit", "stones", "equipment_serial"]:
		if not whole(data[field]):
			return false
	if not whole(data.lethal_guards, 0, 1) or not data.materials is Dictionary or not data.upgrades is Dictionary or not data.equipment_rewards is Array:
		return false
	for id in data.materials:
		if not rules.material_names.has(id) or not whole(data.materials[id], 1):
			return false
	for id in data.upgrades:
		if not rules.upgrades.has(id) or not whole(data.upgrades[id], 1, rules.upgrades[id].cap):
			return false
	var item_ids: Dictionary = {}
	for item in data.equipment_rewards:
		if not item is Dictionary or not item.get("instance_id") is String or item.instance_id.is_empty() or item_ids.has(item.instance_id) or not rules.equipment.has(item.get("item_id")) or item.get("name") != rules.equipment[item.item_id].name:
			return false
		item_ids[item.instance_id] = true
	if not _flags(data.claimed) or not _flags(data.chosen) or not data.offers is Dictionary or not data.shops is Dictionary:
		return false
	for source in data.offers:
		if not source is String or source.is_empty() or not data.offers[source] is Array or data.offers[source].size() > 3:
			return false
		var ids: Dictionary = {}
		for id in data.offers[source]:
			if not rules.upgrades.has(id) or rules.upgrades[id].weight <= 0 or ids.has(id):
				return false
			ids[id] = true
	for source in data.chosen:
		if not data.offers.has(source):
			return false
	for source in data.shops:
		if not source is String or source.is_empty() or not data.shops[source] is Dictionary or data.shops[source].size() != rules.goods.size():
			return false
		for id in rules.goods:
			if not data.shops[source].has(id) or not whole(data.shops[source][id], 0, rules.goods[id].stock):
				return false
	seed = int(data.seed)
	run_id = data.run_id
	spirit = int(data.spirit)
	stones = int(data.stones)
	materials = data.materials.duplicate(true)
	for id in materials:
		materials[id] = int(materials[id])
	equipment_rewards = data.equipment_rewards.duplicate(true)
	upgrades = data.upgrades.duplicate(true)
	for id in upgrades:
		upgrades[id] = int(upgrades[id])
	ended = data.ended
	_drop_rng.state = int(data.drop_rng_state)
	_upgrade_rng.state = int(data.upgrade_rng_state)
	_claimed = data.claimed.duplicate(true)
	_offers = data.offers.duplicate(true)
	_chosen = data.chosen.duplicate(true)
	_shops = data.shops.duplicate(true)
	for source in _shops:
		for id in _shops[source]:
			_shops[source][id] = int(_shops[source][id])
	_lethal_guards = int(data.lethal_guards)
	_equipment_serial = int(data.equipment_serial)
	changed.emit()
	return true
