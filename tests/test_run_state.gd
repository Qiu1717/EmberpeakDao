extends SceneTree

var checks := 0
var failures := 0
var state_script: Script
var rules: Resource

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
	check(FileAccess.file_exists("res://scripts/roguelite/run_state.gd"), "局内规则存在并可执行")
	if failures > 0:
		quit(1)
		return
	state_script = load("res://scripts/roguelite/run_state.gd")
	rules = load("res://resources/roguelite/nameless_tomb_rules.tres")
	_test_rewards()
	_test_rng()
	_test_upgrades()
	_test_events()
	_test_shop()
	_test_finish()
	if failures == 0:
		print("RUN_STATE_CHECKS_PASSED=", checks)
	quit(1 if failures else 0)

func _test_rewards() -> void:
	var run = state_script.new(37)
	var grants: Array = []
	var drops: Array = []
	run.reward_granted.connect(func(payload: Dictionary): grants.append(payload))
	run.equipment_dropped.connect(func(record: Dictionary): drops.append(record))
	check(not run.claim_enemy("bad", "missing").accepted and run.spirit == 0, "未知敌人不给奖励")
	check(not run.claim_enemy("", "shan_xiao").accepted, "空来源不给奖励")
	var reward: Dictionary = run.claim_enemy("enemy:1", "shan_xiao")
	check(reward.accepted and run.spirit == 12 and run.stones == 6, "击杀奖励实际进入局内余额")
	check(not run.claim_enemy("enemy:1", "mountain_general").accepted and grants.size() == 1, "同一死亡来源改敌人ID也不能二次领取")
	var elite: Dictionary = run.claim_enemy("elite:1", "armored_xiao")
	check(elite.accepted and run.materials.get("demon_blood_crystal", 0) == 1 and not run.materials.has("foundation_marrow"), "精英获得妖血结晶且绝不掉筑基灵髓")
	var boss: Dictionary = run.claim_enemy("boss:1", "mountain_general")
	check(boss.accepted and run.materials.get("foundation_marrow", 0) == 1 and boss.equipment.size() == 1 and boss.equipment[0].item_id == "po_shan", "Boss实际发一份筑基灵髓及武器实例")
	check(not run.claim_enemy("boss:1", "mountain_general").accepted and run.materials.foundation_marrow == 1, "重复Boss死亡不重复发材料")
	var before: int = run.equipment_rewards.size()
	var chest: Dictionary = run.claim_chest("chest:1")
	check(chest.accepted and run.equipment_rewards.size() == before + 1 and run.spirit == 212 and run.stones == 141, "宝箱实际发资源与一件装备")
	check(not run.claim_chest("chest:1").accepted and drops.size() == run.equipment_rewards.size(), "宝箱去重且每个装备实例只发一次信号")
	var ids: Dictionary = {}
	for record: Dictionary in run.equipment_rewards:
		check(record.has("name") and not ids.has(record.instance_id) and record.instance_id.begins_with(run.run_id), "装备实例带名称及本局唯一ID")
		ids[record.instance_id] = true
	var never: Resource = rules.duplicate(true)
	never.enemies.shan_xiao.material_chance = 0.0
	never.enemies.shan_xiao.equipment_chance = 0.0
	var always: Resource = rules.duplicate(true)
	always.enemies.shan_xiao.material_chance = 1.0
	always.enemies.shan_xiao.equipment_chance = 1.0
	var zero = state_script.new(100, never)
	var one = state_script.new(100, always)
	for index in 12:
		zero.claim_enemy("enemy:%s" % index, "shan_xiao")
		one.claim_enemy("enemy:%s" % index, "shan_xiao")
	check(zero.materials.is_empty() and zero.equipment_rewards.is_empty(), "概率0不会掉材料或装备")
	check(one.materials.get("demon_blood_crystal", 0) == 12 and one.equipment_rewards.size() == 12, "概率1每次真实生成材料和装备")

func _test_rng() -> void:
	var first = state_script.new(771)
	var second = state_script.new(771)
	first.offer_upgrades("room:0")
	first.offer_upgrades("room:1")
	var first_loot: Array = []
	var second_loot: Array = []
	for index in 25:
		var a: Dictionary = first.claim_enemy("source:%s" % index, "shan_xiao")
		var b: Dictionary = second.claim_enemy("source:%s" % index, "shan_xiao")
		first_loot.append([a.materials, _item_ids(a.equipment)])
		second_loot.append([b.materials, _item_ids(b.equipment)])
	check(first_loot == second_loot, "同seed掉落重现且强化抽取不污染掉落随机流")
	var third = state_script.new(771)
	check(second.offer_upgrades("room:0") == third.offer_upgrades("room:0"), "掉落抽取不污染强化随机流")
	var options: Array = first.offer_upgrades("room:cached")
	var original := options.duplicate()
	options.clear()
	check(first.offer_upgrades("room:cached") == original, "同一来源缓存选项且外部修改返回值不重抽")
	check(first.run_id != second.run_id, "同seed新探索有独立run_id")

func _item_ids(records: Array) -> Array:
	var result: Array = []
	for record: Dictionary in records:
		result.append(record.item_id)
	return result

func _test_upgrades() -> void:
	var run = state_script.new(80)
	var offered: Array = run.offer_upgrades("room:1")
	var unique: Dictionary = {}
	for upgrade_id: String in offered:
		unique[upgrade_id] = true
	check(offered.size() == 3 and unique.size() == 3 and not offered.has("sword_insight"), "三选一无重复且不含事件专属攻击")
	check(not run.choose_upgrade("room:1", "sword_insight") and not run.choose_upgrade("unoffered", "attack"), "不能选池外强化或未发出的选项")
	check(run.choose_upgrade("room:1", offered[0]) and not run.choose_upgrade("room:1", offered[1]), "同来源只接受一次合法三选一")
	check(run.offer_upgrades("room:1").is_empty(), "领取后的房间不再次展示奖励")
	var attack_rules: Resource = rules.duplicate(true)
	for key in attack_rules.upgrades.keys():
		if key != "attack":
			attack_rules.upgrades.erase(key)
	var stacked = state_script.new(8, attack_rules)
	for index in 3:
		check(stacked.offer_upgrades("cap:%s" % index) == ["attack"] and stacked.choose_upgrade("cap:%s" % index, "attack"), "仅剩可用强化时按实际上限提供选项")
	check(stacked.offer_upgrades("cap:full").is_empty() and is_equal_approx(stacked.stat_modifiers().attack_multiplier, 1.15), "攻击三层加法叠加，上限后退出奖池")
	var all = state_script.new(6)
	for key in ["attack", "health", "defense", "crit", "dodge", "haste"]:
		for attempt in 100:
			var source := "%s:%s" % [key, attempt]
			if all.offer_upgrades(source).has(key):
				all.choose_upgrade(source, key)
				break
	var mods: Dictionary = all.stat_modifiers()
	check(is_equal_approx(mods.attack_multiplier, 1.05) and mods.health_bonus == 10 and mods.defense_bonus == 3 and is_equal_approx(mods.crit_bonus, 0.04) and is_equal_approx(mods.dodge_reduction, 0.08) and is_equal_approx(mods.haste, 0.05), "六种强化给出相对基础属性的真实修正量")

func _test_events() -> void:
	var run = state_script.new(91)
	var grants: Array = []
	run.reward_granted.connect(func(payload: Dictionary): grants.append(payload))
	check(not run.resolve_event("event:1", "sword_question", "invalid", 99, 100).accepted, "非法奇遇选项不会完成事件")
	var answer: Dictionary = run.resolve_event("event:1", "sword_question", "a", 99, 100)
	check(answer.accepted and answer.health_cost == 14 and is_equal_approx(run.stat_modifiers().attack_multiplier, 1.2), "残剑问心扣当前生命15%向下取整且攻击加20%")
	check(grants[0].health_cost == 14 and grants[0].message == answer.message, "奇遇信号携带与返回值一致的生命代价和事件信息")
	check(not run.resolve_event("event:1", "sword_question", "b", 85, 100).accepted and run.spirit == 0, "奇遇已选A后不能再领B")
	check(not run.resolve_event("event:2", "sword_question", "a", 10, 100).accepted, "事件专属攻击达到上限时不再付生命")
	var safe: Dictionary = run.resolve_event("event:2", "sword_question", "b", 10, 100)
	check(safe.accepted and safe.health_cost == 0 and run.spirit == 10, "失败可重选安全选项并获得灵气")
	check(not run.resolve_event("well:1", "well_echo", "a", 100, 100).accepted, "满血灵泉不消耗事件，可改选")
	var heal: Dictionary = run.resolve_event("well:1", "well_echo", "a", 80, 100)
	check(heal.accepted and heal.health_restored == 20, "古井恢复按缺血截断")
	var equipment_before: int = run.equipment_rewards.size()
	check(run.resolve_event("well:2", "well_echo", "b", 10, 100).accepted and run.equipment_rewards.size() == equipment_before + 1, "探井实际生成装备实例")
	check(not run.resolve_event("well:2", "sword_question", "b", 10, 100).accepted, "同一奇遇来源换事件ID不能重复领奖")
	var low = state_script.new(92)
	check(low.resolve_event("one_hp", "sword_question", "a", 1, 100).health_cost == 0, "一血按向下取整代价零，不造成致死")

func _test_shop() -> void:
	var run = state_script.new(12)
	var inventory: Array = run.shop_inventory("shop:1")
	check(inventory.size() == 3 and inventory[0].remaining == 2, "店铺展示三个有价有库存商品")
	inventory[0].remaining = 0
	check(run.shop_inventory("shop:1")[0].remaining == 2, "UI不能修改实际库存")
	check(not run.buy("shop:1", "heal", 20, 100).accepted and run.stones == 0 and run.shop_inventory("shop:1")[0].remaining == 2, "余额不足不扣库存或灵石")
	run.claim_enemy("boss", "mountain_general")
	check(not run.buy("shop:1", "heal", 100, 100).accepted and run.stones == 80, "满血不能付款买治疗")
	check(not run.buy("shop:1", "missing", 50, 100).accepted and run.stones == 80, "未知商品不扣费")
	check(run.buy("shop:1", "heal", 90, 100).health_restored == 10 and run.stones == 68, "治疗实际按缺血回复并扣一次价格")
	check(run.buy("shop:1", "heal", 20, 100).health_restored == 35 and run.stones == 56, "第二份治疗按完整值回复")
	check(not run.buy("shop:1", "heal", 20, 100).accepted and run.stones == 56, "库存耗尽不重复扣款")
	check(run.buy("shop:1", "talisman", 20, 100).accepted and run.stones == 16, "替劫符实际扣款并获得一次防致死能力")
	check(run.use_lethal_guard() and not run.use_lethal_guard(), "替劫符只保护一次且当场消耗")
	run.claim_chest("fund")
	check(run.buy("shop:1", "attack", 20, 100).accepted and run.stones == 16 and is_equal_approx(run.stat_modifiers().attack_multiplier, 1.05), "购买攻击与随机攻击共用属性修正")
	check(not run.buy("shop:1", "attack", 20, 100).accepted and run.stones == 16, "攻击商品售罄后不扣款")
	var capped = state_script.new(41)
	capped.claim_enemy("boss", "mountain_general")
	for index in 3:
		capped.buy("shop:%s" % index, "attack", 20, 100)
	check(not capped.buy("shop:cap", "attack", 20, 100).accepted and capped.stones == 20 and capped.shop_inventory("shop:cap")[1].remaining == 1, "效果达上限拒绝购买，库存和余额都保留")

func _test_finish() -> void:
	var run = state_script.new(5)
	run.claim_enemy("boss", "mountain_general")
	run.buy("shop", "talisman", 50, 100)
	run.resolve_event("sword", "sword_question", "a", 50, 100)
	run.offer_upgrades("pending")
	var summary: Dictionary = run.finish_run("death")
	check(summary.reason == "death" and summary.spirit == 120 and summary.stones == 40 and summary.materials.foundation_marrow == 1 and summary.equipment_rewards.size() == 1, "死亡摘要保留结束前的实际结算")
	check(run.ended and run.spirit == 0 and run.stones == 0 and run.materials.is_empty() and run.equipment_rewards.is_empty() and run.upgrades.is_empty() and not run.use_lethal_guard(), "结束清空余额、材料、装备、强化及替劫符")
	check(run.stat_modifiers().attack_multiplier == 1.0 and run.offer_upgrades("pending").is_empty() and run.shop_inventory("shop").is_empty(), "结束后基础属性恢复且选项库存不可使用")
	check(not run.claim_enemy("after", "mountain_general").accepted and not run.claim_chest("after").accepted and not run.buy("after", "heal", 10, 100).accepted and not run.resolve_event("after", "well_echo", "b", 10, 100).accepted and not run.choose_upgrade("pending", "attack"), "结束后所有领取与操作入口拒绝修改")
	var fresh = state_script.new(6)
	check(not fresh.ended and fresh.spirit == 0 and fresh.stones == 0 and fresh.upgrades.is_empty() and fresh.claim_enemy("boss", "mountain_general").accepted and fresh.materials.foundation_marrow == 1, "新局不继承旧局状态且Boss材料可重新获取")
