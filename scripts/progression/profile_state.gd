extends RefCounted

const RUN_RULES = preload("res://resources/roguelite/nameless_tomb_rules.tres")
const WEAPON_IDS := ["qing_feng", "po_shan"]
const BLUEPRINT_IDS := ["qing_feng", "po_shan", "qing_bu", "can_jian", "hui_ling", "xuan_wen"]
const BOSS_IDS := ["mountain_general"]
const MAX_BALANCE := 9223372036854775807

var rules: Resource
var realm := 0
var subrealm := 0
var banked_spirit := 0
var banked_stones := 0
var banked_materials: Dictionary = {}
var weapon_unlocks: Array = ["qing_feng"]
var blueprints: Array = []
var boss_kills: Array = []

func _init(rules_data: Resource = null) -> void:
	rules = rules_data if rules_data != null else load("res://resources/realms/first_map_realms.tres")

func to_dict() -> Dictionary:
	return {
		"realm": realm, "subrealm": subrealm,
		"banked_spirit": banked_spirit, "banked_stones": banked_stones,
		"banked_materials": banked_materials.duplicate(true),
		"weapon_unlocks": weapon_unlocks.duplicate(),
		"blueprints": blueprints.duplicate(), "boss_kills": boss_kills.duplicate()
	}

func restore(data: Dictionary) -> bool:
	for key in ["realm", "subrealm", "banked_spirit", "banked_stones"]:
		if not _whole(data.get(key)):
			return false
	if rules.current(int(data.realm), int(data.subrealm)).is_empty():
		return false
	if not _valid_materials(data.get("banked_materials")):
		return false
	if not _valid_ids(data.get("weapon_unlocks"), WEAPON_IDS) or not _valid_ids(data.get("blueprints"), BLUEPRINT_IDS) or not _valid_ids(data.get("boss_kills"), BOSS_IDS):
		return false
	realm = int(data.realm)
	subrealm = int(data.subrealm)
	banked_spirit = int(data.banked_spirit)
	banked_stones = int(data.banked_stones)
	banked_materials = _copy_materials(data.banked_materials)
	weapon_unlocks = data.weapon_unlocks.duplicate()
	blueprints = data.blueprints.duplicate()
	boss_kills = data.boss_kills.duplicate()
	return true

func advance_minor(pending: int) -> Dictionary:
	var result := {"accepted": false, "pending": pending, "breakthroughs": []}
	if pending < 0:
		return result
	while subrealm < 3:
		var stage: Dictionary = stats()
		var following: Dictionary = rules.next(realm, subrealm)
		if stage.is_empty() or following.is_empty() or following.realm != realm:
			break
		var cost: int = stage.required_spirit
		if cost <= 0 or not _affordable(cost, result.pending):
			break
		result.pending = _consume_spirit(cost, result.pending)
		subrealm = following.subrealm
		result.breakthroughs.append(following.name)
		result.accepted = true
	return result

func major_breakthrough(pending: int, pending_materials: Dictionary, at_altar: bool) -> Dictionary:
	var result := {"accepted": false, "message": "", "pending": pending, "materials": pending_materials.duplicate(true)}
	if pending < 0 or not _valid_materials(pending_materials):
		result.message = "突破资源无效"
		return result
	if not at_altar:
		result.message = "请在灵脉祭坛确认大境界突破"
		return result
	var stage: Dictionary = stats()
	var following: Dictionary = rules.next(realm, subrealm)
	if subrealm != 3:
		result.message = "须先达到当前大境界圆满"
		return result
	if stage.is_empty() or following.is_empty() or following.realm != realm + 1 or following.subrealm != 0 or stage.required_spirit <= 0:
		result.message = "当前阶段没有可用的后续境界配置"
		return result
	if not _affordable(stage.required_spirit, pending):
		result.message = "丹田灵气不足"
		return result
	var material: String = stage.material_id
	if not RUN_RULES.material_names.has(material) or (pending_materials.get(material, 0) < 1 and banked_materials.get(material, 0) < 1):
		result.message = "缺少对应Boss突破材料"
		return result
	result.pending = _consume_spirit(stage.required_spirit, pending)
	if pending_materials.get(material, 0) > 0:
		result.materials[material] = int(pending_materials[material]) - 1
	else:
		banked_materials[material] = int(banked_materials[material]) - 1
	realm = following.realm
	subrealm = following.subrealm
	result.accepted = true
	result.message = "已突破至" + following.name
	return result

func record_resources(spirit: int, stones: int, materials: Dictionary) -> bool:
	if spirit < 0 or stones < 0 or spirit > MAX_BALANCE - banked_spirit or stones > MAX_BALANCE - banked_stones or not _valid_materials(materials):
		return false
	for id: String in materials:
		if int(materials[id]) > MAX_BALANCE - int(banked_materials.get(id, 0)):
			return false
	banked_spirit += spirit
	banked_stones += stones
	for id: String in materials:
		banked_materials[id] = int(banked_materials.get(id, 0)) + int(materials[id])
	return true

func stats() -> Dictionary:
	return rules.current(realm, subrealm)

func _affordable(cost: int, pending: int) -> bool:
	return pending >= cost or banked_spirit >= cost - pending

func _consume_spirit(cost: int, pending: int) -> int:
	var from_pending := mini(cost, pending)
	banked_spirit -= cost - from_pending
	return pending - from_pending

func _whole(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= 0
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value >= 0.0 and value < 9223372036854775808.0 and floor(value) == value

func _valid_materials(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	for id: Variant in value:
		if typeof(id) != TYPE_STRING or not RUN_RULES.material_names.has(id) or not _whole(value[id]):
			return false
	return true

func _copy_materials(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id: String in value:
		result[id] = int(value[id])
	return result

func _valid_ids(value: Variant, allowed: Array) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var seen: Dictionary = {}
	for id: Variant in value:
		if typeof(id) != TYPE_STRING or not allowed.has(id) or seen.has(id):
			return false
		seen[id] = true
	return true
