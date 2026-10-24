extends RefCounted

const SLOTS := ["weapon", "armor", "accessory"]
const REALM_NAMES := ["炼气", "筑基", "金丹", "元婴", "化神"]

var catalog: Resource
var items: Array = []
var equipped: Dictionary = {}

func _init(catalog_data: Resource = null) -> void:
	catalog = catalog_data if catalog_data != null else load("res://resources/equipment/first_map_equipment.tres")

func add_item(record: Dictionary) -> Dictionary:
	if not _valid_record(record):
		return _reject("装备实例资料无效或物品不存在")
	if not _find_record(record.instance_id).is_empty():
		return _reject("该装备实例已经持有")
	items.append(record.duplicate(true))
	return {"accepted": true, "message": "获得" + record.name}

func equip(instance_id: String, realm: int) -> Dictionary:
	var record := _find_record(instance_id)
	if record.is_empty():
		return _reject("未持有该装备实物")
	var item: Dictionary = catalog.items[record.item_id]
	if not _can_equip(item, realm):
		return _reject("当前境界不符合该装备的品阶或境界要求")
	equipped[item.slot] = instance_id
	return {"accepted": true, "message": "已装备" + item.name}

func unequip(slot: String) -> Dictionary:
	if not SLOTS.has(slot) or not equipped.has(slot):
		return _reject("该槽位没有可卸下的装备")
	equipped.erase(slot)
	return {"accepted": true, "message": "已卸下装备"}

func modifiers() -> Dictionary:
	var result := {"health_bonus": 0, "defense_bonus": 0, "third_attack_multiplier": 1.0, "qi_regen_multiplier": 1.0, "qi_bonus": 0, "attack_bonus": 0}
	for slot: String in SLOTS:
		var record := _find_record(equipped.get(slot, ""))
		if record.is_empty():
			continue
		var item: Dictionary = catalog.items[record.item_id]
		if item.slot != slot:
			continue
		var effects: Dictionary = item.effects
		result.health_bonus += effects.get("max_health", 0)
		result.defense_bonus += effects.get("defense", 0)
		result.qi_bonus += effects.get("max_qi", 0)
		result.third_attack_multiplier += effects.get("third_attack_multiplier", 0.0)
		result.qi_regen_multiplier += effects.get("qi_regen_multiplier", 0.0)
	return result

func weapon_id() -> String:
	var record := _find_record(equipped.get("weapon", ""))
	if record.is_empty() or catalog.items[record.item_id].slot != "weapon":
		return ""
	return record.item_id

func to_dict() -> Dictionary:
	return {"items": items.duplicate(true), "equipped": equipped.duplicate(true)}

func restore(data: Dictionary, realm: int = 0) -> bool:
	if realm < 0 or realm >= REALM_NAMES.size() or data.size() != 2 or not data.get("items") is Array or not data.get("equipped") is Dictionary:
		return false
	var candidate = get_script().new(catalog)
	for record in data.items:
		if not record is Dictionary or not candidate.add_item(record).accepted:
			return false
	for slot in data.equipped:
		if not slot is String or not SLOTS.has(slot) or not data.equipped[slot] is String:
			return false
		var record: Dictionary = candidate._find_record(data.equipped[slot])
		if record.is_empty() or catalog.items[record.item_id].slot != slot:
			return false
		if not candidate.equip(record.instance_id, realm).accepted:
			return false
	items = candidate.items
	equipped = candidate.equipped
	return true

func _valid_record(record: Dictionary) -> bool:
	if record.size() != 3:
		return false
	for field: String in ["instance_id", "item_id", "name"]:
		if not record.get(field) is String or record[field].is_empty():
			return false
	return catalog.items.has(record.item_id) and record.name == catalog.items[record.item_id].name

func _find_record(instance_id: String) -> Dictionary:
	for record: Dictionary in items:
		if record.instance_id == instance_id:
			return record
	return {}

func _can_equip(item: Dictionary, realm: int) -> bool:
	return realm >= 0 and realm < REALM_NAMES.size() and SLOTS.has(item.slot) and realm >= item.required_realm and realm >= item.tier

func _reject(message: String) -> Dictionary:
	return {"accepted": false, "message": message}
