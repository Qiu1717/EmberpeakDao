extends SceneTree

var checks := 0
var failures := 0
var inventory_script: Script
var catalog: Resource

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/inventory/inventory_state.gd") and FileAccess.file_exists("res://resources/equipment/first_map_equipment.tres"), "真实装备实例与目录模块存在")
	if failures > 0:
		quit(1)
		return
	inventory_script = load("res://scripts/inventory/inventory_state.gd")
	catalog = load("res://resources/equipment/first_map_equipment.tres")
	_test_items()
	_test_requirements()
	_test_modifiers()
	_test_restore()
	if failures == 0:
		print("INVENTORY_CHECKS_PASSED=", checks)
	quit(1 if failures else 0)

func _record(instance_id: String, item_id: String) -> Dictionary:
	return {"instance_id": instance_id, "item_id": item_id, "name": catalog.items[item_id].name}

func _test_items() -> void:
	var inventory = inventory_script.new()
	check(inventory.items.is_empty() and inventory.weapon_id().is_empty(), "空背包不会虚构已解锁基础武器实物")
	check(not inventory.add_item({"instance_id": "run:bad", "item_id": "unknown", "name": "未知"}).accepted, "未知物品不能入包")
	for bad in [{}, {"instance_id": "", "item_id": "qing_feng", "name": "青锋旧剑"}, {"instance_id": 1, "item_id": "qing_feng", "name": "青锋旧剑"}, {"instance_id": "run:bad", "item_id": "qing_feng", "name": 1}]:
		check(not inventory.add_item(bad).accepted and inventory.items.is_empty(), "坏实例字段拒绝且不污染背包")
	var record := _record("run:1", "qing_feng")
	check(inventory.add_item(record).accepted and inventory.items.size() == 1, "真实实例可加入背包")
	record.name = "篡改返回外的来源"
	check(inventory.items[0].name == "青锋旧剑", "加入背包复制实物记录而非共享引用")
	check(not inventory.add_item(_record("run:1", "po_shan")).accepted and inventory.items.size() == 1, "重复instance_id即使换物品也不能重复入包")
	check(not inventory.equip("not-owned", 0).accepted and inventory.equipped.is_empty(), "不能装备未持有的实例")
	check(inventory.equip("run:1", 0).accepted and inventory.weapon_id() == "qing_feng" and catalog.items[inventory.weapon_id()].damage == [14, 18, 24], "装备青锋旧剑后读取实际三段基础伤害")
	inventory.add_item(_record("run:2", "po_shan"))
	check(inventory.equip("run:2", 0).accepted and inventory.weapon_id() == "po_shan" and inventory.equipped.weapon == "run:2" and catalog.items[inventory.weapon_id()].damage == [22, 28, 38], "更换武器槽后伤害标识与破山三段伤害切换")
	check(inventory.items.size() == 2, "更换武器不会删除原武器实物")
	check(inventory.unequip("weapon").accepted and inventory.weapon_id().is_empty(), "卸下武器后不再返回已解锁武器或旧武器")
	check(not inventory.unequip("weapon").accepted and not inventory.unequip("unknown").accepted, "空槽与未知槽不能伪称卸下成功")
	for id: String in catalog.items:
		var item: Dictionary = catalog.items[id]
		check(item.has("name") and item.has("slot") and item.has("tier") and item.has("required_realm") and item.has("rarity") and item.has("effects") and item.has("icon_path"), "实际目录保留品阶、境界、稀有度与效果字段：" + id)
		check(item.icon_path == "" if id == "xuan_wen" else FileAccess.file_exists(item.icon_path), "图标只引用已有概念素材，无素材保留空路径：" + id)

func _test_requirements() -> void:
	var inventory = inventory_script.new(catalog)
	inventory.add_item(_record("run:armor", "xuan_wen"))
	inventory.add_item(_record("run:jade", "hui_ling"))
	check(not inventory.equip("run:armor", 0).accepted and not inventory.equip("run:jade", 0).accepted and inventory.equipped.is_empty(), "炼气不能装备筑基防具或饰品")
	check(inventory.equip("run:armor", 1).accepted and inventory.equip("run:jade", 1).accepted, "达到筑基后可真实装备筑基物品")
	check(not inventory.equip("run:armor", -1).accepted and not inventory.equip("run:armor", 5).accepted, "非法境界编号不能用来穿戴")
	var tier_catalog: Resource = catalog.duplicate(true)
	tier_catalog.items.qing_bu.tier = 1
	tier_catalog.items.qing_bu.required_realm = 0
	tier_catalog.items.qing_bu.rarity = "common"
	var tier_inventory = inventory_script.new(tier_catalog)
	tier_inventory.add_item(_record("run:tier", "qing_bu"))
	check(not tier_inventory.equip("run:tier", 0).accepted and tier_inventory.equipped.is_empty(), "降低单独required_realm或使用普通稀有度不能绕过灵器品阶门槛")
	tier_catalog.items.qing_bu.rarity = "legendary"
	check(not tier_inventory.equip("run:tier", 0).accepted and tier_inventory.equip("run:tier", 1).accepted, "稀有度不改变品阶最低境界，满足品阶才允许装备")

func _test_modifiers() -> void:
	var inventory = inventory_script.new(catalog)
	var base := {"health_bonus": 0, "defense_bonus": 0, "third_attack_multiplier": 1.0, "qi_regen_multiplier": 1.0, "qi_bonus": 0, "attack_bonus": 0}
	check(inventory.modifiers() == base, "未装备时所有基础修正保持原点")
	for entry in [["run:cloth", "qing_bu"], ["run:pendant", "can_jian"], ["run:jade", "hui_ling"], ["run:robe", "xuan_wen"]]:
		inventory.add_item(_record(entry[0], entry[1]))
	inventory.equip("run:cloth", 0)
	inventory.equip("run:pendant", 0)
	var mods: Dictionary = inventory.modifiers()
	check(mods.health_bonus == 10 and mods.defense_bonus == 3 and is_equal_approx(mods.third_attack_multiplier, 1.10) and mods.qi_regen_multiplier == 1.0 and mods.qi_bonus == 0, "青布与残剑坠只对生命、防御和第三段伤害产生正式数值")
	for index in 4:
		inventory.equip("run:cloth", 0)
		inventory.equip("run:pendant", 0)
	check(inventory.modifiers() == mods, "重复穿戴同一实例不会叠加属性")
	inventory.equip("run:jade", 1)
	mods = inventory.modifiers()
	check(inventory.equipped.accessory == "run:jade" and mods.third_attack_multiplier == 1.0 and is_equal_approx(mods.qi_regen_multiplier, 1.15), "一饰品槽替换后撤销残剑坠并提供回灵玉佩真气恢复")
	inventory.equip("run:robe", 1)
	mods = inventory.modifiers()
	check(mods.health_bonus == 0 and mods.defense_bonus == 8 and mods.qi_bonus == 10, "玄纹替换青布后撤销旧生命与防御，提供自身防御和真气")
	for index in 3:
		inventory.unequip("armor")
		inventory.equip("run:robe", 1)
	inventory.unequip("armor")
	inventory.unequip("accessory")
	check(inventory.modifiers() == base, "重复装卸真实装备后所有修正准确归零")
	mods = inventory.modifiers()
	mods.health_bonus = 999
	check(inventory.modifiers() == base, "外部修改返回修正不会改变装备或后续重算结果")

func _test_restore() -> void:
	var inventory = inventory_script.new(catalog)
	inventory.add_item(_record("run:weapon", "qing_feng"))
	inventory.add_item(_record("run:cloth", "qing_bu"))
	inventory.equip("run:weapon", 0)
	inventory.equip("run:cloth", 0)
	var saved: Dictionary = inventory.to_dict()
	var loaded = inventory_script.new(catalog)
	var decoded = JSON.parse_string(JSON.stringify(saved))
	check(loaded.restore(decoded, 0) and loaded.to_dict() == saved and loaded.weapon_id() == "qing_feng" and loaded.modifiers().health_bonus == 10, "JSON往返恢复真实物品、槽位与重算属性")
	var exported: Dictionary = loaded.to_dict()
	exported.items[0].name = "外部改名"
	exported.equipped.clear()
	check(loaded.to_dict() == saved, "导出深复制，外部改快照不能修改现有物品与槽位")
	var corruptions: Array = [{}, {"items": {}, "equipped": {}}, {"items": [], "equipped": []}]
	var duplicate: Dictionary = saved.duplicate(true)
	duplicate.items.append(duplicate.items[0].duplicate(true))
	corruptions.append(duplicate)
	var unknown: Dictionary = saved.duplicate(true)
	unknown.items[0].item_id = "unknown"
	corruptions.append(unknown)
	var missing: Dictionary = saved.duplicate(true)
	missing.equipped.weapon = "not-owned"
	corruptions.append(missing)
	var wrong_slot: Dictionary = saved.duplicate(true)
	wrong_slot.equipped.armor = "run:weapon"
	corruptions.append(wrong_slot)
	var duplicate_slot: Dictionary = saved.duplicate(true)
	duplicate_slot.equipped.accessory = "run:weapon"
	corruptions.append(duplicate_slot)
	var unknown_slot: Dictionary = saved.duplicate(true)
	unknown_slot.equipped.extra = "run:weapon"
	corruptions.append(unknown_slot)
	var wrong_type: Dictionary = saved.duplicate(true)
	wrong_type.equipped.weapon = 42
	corruptions.append(wrong_type)
	var malformed_record: Dictionary = saved.duplicate(true)
	malformed_record.items[0] = "not-a-record"
	corruptions.append(malformed_record)
	for index in corruptions.size():
		check(not loaded.restore(corruptions[index], 0) and loaded.to_dict() == saved, "损坏快照拒绝且原有状态不动：%d" % index)
	var high = inventory_script.new(catalog)
	high.add_item(_record("run:high", "xuan_wen"))
	high.equip("run:high", 1)
	check(not loaded.restore(high.to_dict(), 0) and loaded.to_dict() == saved, "读档不能把筑基装备静默穿到炼气身上")
	check(loaded.restore(high.to_dict(), 1) and loaded.modifiers().defense_bonus == 8 and loaded.modifiers().qi_bonus == 10, "符合境界时恢复高境界装备并重新计算属性")
	high.unequip("armor")
	check(loaded.restore(high.to_dict(), 0) and loaded.equipped.is_empty() and loaded.items.size() == 1, "境界不足仍可持有或收藏未穿戴的高阶实物")
	var before: Dictionary = loaded.to_dict()
	check(not loaded.restore(saved, 5) and loaded.to_dict() == before, "非法恢复境界不污染原状态")
	check(loaded.restore({"items": [], "equipped": {}}, 0) and loaded.items.is_empty() and loaded.modifiers().defense_bonus == 0, "死亡新局提供空快照后不保留任何装备实物修正")
