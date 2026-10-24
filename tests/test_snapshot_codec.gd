extends SceneTree

const Profile := preload("res://scripts/progression/profile_state.gd")
const Run := preload("res://scripts/roguelite/run_state.gd")
const Inventory := preload("res://scripts/inventory/inventory_state.gd")

var checks := 0
var failures := 0
var codec: Script

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _entry() -> Dictionary:
	var profile := Profile.new()
	var run := Run.new(20261024)
	var inventory := Inventory.new()
	inventory.add_item({"instance_id": "base:qing_feng", "item_id": "qing_feng", "name": "青锋旧剑"})
	inventory.equip("base:qing_feng", 0)
	return {"save_version": 1, "revision": 1, "profile": profile.to_dict(), "run_snapshot": {"run": run.to_dict(), "inventory": inventory.to_dict(), "current_id": "entry", "visited": {"entry": true}, "cleared_rooms": {"entry": true}, "upgrade_pending": {}, "health": 100, "qi": 60.0, "enemies": {}}}

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/save/snapshot_codec.gd"), "完整快照校验器存在且可执行")
	if failures > 0:
		quit(1)
		return
	codec = load("res://scripts/save/snapshot_codec.gd")
	_test_entry()
	_test_structure()
	_test_inventory()
	_test_health_bonuses()
	_test_rooms()
	_test_enemy_armor()
	if failures == 0:
		print("SNAPSHOT_CODEC_CHECKS_PASSED=", checks)
	quit(1 if failures else 0)

func _test_entry() -> void:
	var valid := _entry()
	var before: Dictionary = valid.duplicate(true)
	check(codec.validate(valid) and valid == before, "真实入口快照可验证且输入不被修改")
	check(codec.validate(JSON.parse_string(JSON.stringify(valid))), "JSON数字转换后仍可恢复真实入口快照")
	valid.run_snapshot = null
	check(codec.validate(valid), "无活跃探索的完整永久档案合法")
	valid.profile.banked_spirit = 2.5
	check(not codec.validate(valid), "无活跃探索也必须校验永久档案")

func _test_structure() -> void:
	for change in [{"save_version": true}, {"save_version": 2}, {"revision": 0}, {"revision": 1.1}, {"revision": "1"}, {"profile": []}, {"run_snapshot": []}]:
		var invalid := _entry()
		invalid.merge(change, true)
		check(not codec.validate(invalid), "畸形封套字段被整体拒绝")
	for key in ["save_version", "revision", "profile", "run_snapshot"]:
		var invalid := _entry()
		invalid.erase(key)
		check(not codec.validate(invalid), "缺少封套字段%s不能加载" % key)
	for key in ["run", "inventory", "current_id", "visited", "cleared_rooms", "upgrade_pending", "health", "qi", "enemies"]:
		var invalid := _entry()
		invalid.run_snapshot.erase(key)
		check(not codec.validate(invalid), "缺少快照字段%s不能加载" % key)
	for change in [{"run": []}, {"inventory": []}, {"current_id": 1}, {"current_id": "unknown"}, {"visited": []}, {"visited": {"entry": false}}, {"visited": {"entry": 1}}, {"visited": {"unknown": true}}, {"visited": {}}, {"cleared_rooms": {"boss": true}}, {"upgrade_pending": []}, {"enemies": []}, {"health": 0}, {"health": true}, {"health": 1.2}, {"health": 101}, {"qi": -1.0}, {"qi": INF}, {"qi": NAN}, {"qi": true}, {"qi": "60"}, {"qi": 60.01}]:
		var invalid := _entry()
		invalid.run_snapshot.merge(change, true)
		check(not codec.validate(invalid), "快照嵌套类型、地图ID、flags或生命真气范围无效时拒绝")
	for change in [{"ended": true}, {"drop_rng_state": "9223372036854775808"}, {"upgrade_rng_state": "-9223372036854775809"}, {"seed": "18446744073709551616"}, {"materials": {"corpse_iron": true}}, {"equipment_rewards": [null]}, {"offers": {"entry": [null]}}, {"shops": {"side_before": []}}]:
		var invalid := _entry()
		invalid.run_snapshot.run.merge(change, true)
		check(not codec.validate(invalid), "非法RunState和越界RNG字符串安全拒绝")

func _test_inventory() -> void:
	var valid := _entry()
	var run := Run.new(20261024)
	var reward: Dictionary = run.claim_enemy("boss:0", "mountain_general")
	var inventory := Inventory.new()
	inventory.restore(valid.run_snapshot.inventory, 0)
	for record: Dictionary in reward.equipment:
		inventory.add_item(record)
	valid.run_snapshot.run = run.to_dict()
	valid.run_snapshot.inventory = inventory.to_dict()
	check(codec.validate(valid) and codec.validate(JSON.parse_string(JSON.stringify(valid))), "真实奖励候选实物进入库存后完整快照及JSON往返合法")
	var missing: Dictionary = valid.duplicate(true)
	missing.run_snapshot.inventory.items.pop_back()
	check(not codec.validate(missing), "已发装备在库存缺失时不能继续，避免奖励与库存分裂")
	var changed: Dictionary = valid.duplicate(true)
	changed.run_snapshot.inventory.items[-1].instance_id += ":changed"
	check(not codec.validate(changed), "同物品不同实例不能冒充已发装备")
	var invalid := _entry()
	invalid.run_snapshot.inventory.items.append({"instance_id": "high", "item_id": "xuan_wen", "name": "玄纹法衣"})
	invalid.run_snapshot.inventory.equipped["armor"] = "high"
	check(not codec.validate(invalid), "已穿装备必须满足恢复档案的真实境界要求")
	invalid = _entry()
	invalid.run_snapshot.inventory.items[0] = {"instance_id": "base:po_shan", "item_id": "po_shan", "name": "破山长枪"}
	invalid.run_snapshot.inventory.equipped.weapon = "base:po_shan"
	check(not codec.validate(invalid), "未解锁的基础武器不能凭空出现在库存")
	invalid.profile.weapon_unlocks.append("po_shan")
	check(codec.validate(invalid), "已解锁的基础武器允许独立于局内奖励库存存在")

func _test_health_bonuses() -> void:
	var valid := _entry()
	var run_rules: Resource = load("res://resources/roguelite/nameless_tomb_rules.tres").duplicate(true)
	run_rules.chest.equipment_pool = ["qing_bu"]
	var run := Run.new(20261024, run_rules)
	var reward: Dictionary = run.claim_chest("side_before")
	var inventory := Inventory.new()
	inventory.restore(valid.run_snapshot.inventory, 0)
	inventory.add_item(reward.equipment[0])
	inventory.equip(reward.equipment[0].instance_id, 0)
	valid.run_snapshot.run = run.to_dict()
	valid.run_snapshot.inventory = inventory.to_dict()
	valid.run_snapshot.health = 110
	check(codec.validate(valid), "真实道袍增加10生命后允许110生命恢复")
	valid.run_snapshot.health = 111
	check(not codec.validate(valid), "装备生命加成也不能使快照超过实际最大生命")
	for index in 100:
		var source := "health:%s" % index
		if run.offer_upgrades(source).has("health"):
			run.choose_upgrade(source, "health")
			break
	valid.run_snapshot.run = run.to_dict()
	valid.run_snapshot.health = 120
	check(codec.validate(valid), "生命上限统一叠加境界、真实装备和局内强化")

func _combat() -> Dictionary:
	var valid := _entry()
	valid.run_snapshot.current_id = "melee"
	valid.run_snapshot.visited["melee"] = true
	valid.run_snapshot.enemies = {"melee:0": 90, "melee:1": 75}
	return valid

func _test_rooms() -> void:
	var valid := _combat()
	check(codec.validate(valid), "未清战斗房完整真实敌人源和生命可以恢复")
	for enemies in [{}, {"melee:0": 90}, {"melee:0": 91, "melee:1": 75}, {"melee:0": 90, "melee:1": -1}, {"melee:0": true, "melee:1": 75}, {"melee:0": 1.5, "melee:1": 75}, {"melee:0": 90, "melee:1": 75, "unknown": 1}, {"melee:0": 0, "melee:1": 75}]:
		var invalid := _combat()
		invalid.run_snapshot.enemies = enemies
		check(not codec.validate(invalid), "缺失敌人、未知来源、越界生命及未结算死亡均不能恢复")
	valid.run_snapshot.enemies["melee:0"] = 0
	valid.run_snapshot.run.claimed["enemy:melee:0"] = true
	check(codec.validate(valid), "死亡敌人具备已领取标识时允许安全点恢复")
	valid.run_snapshot.cleared_rooms["melee"] = true
	valid.run_snapshot.enemies = {}
	check(codec.validate(valid), "已清场房间允许省略当前敌人快照")
	var run := Run.new(20261024)
	var offered: Array = run.offer_upgrades("melee")
	valid.run_snapshot.run = run.to_dict()
	valid.run_snapshot.upgrade_pending["melee"] = true
	check(codec.validate(valid), "已清战斗房的真实待选三选一候选可继续且不重抽")
	var invalid: Dictionary = valid.duplicate(true)
	invalid.run_snapshot.cleared_rooms.erase("melee")
	check(not codec.validate(invalid), "待选强化必须属于已清场且已访问房间")
	invalid = valid.duplicate(true)
	invalid.run_snapshot.upgrade_pending = {"entry": true}
	check(not codec.validate(invalid), "入口房不能伪装成战斗三选一来源")
	invalid = valid.duplicate(true)
	invalid.run_snapshot.run.offers.erase("melee")
	check(not codec.validate(invalid), "待选标记缺少已缓存候选时拒绝")
	invalid = valid.duplicate(true)
	invalid.run_snapshot.run.offers["melee"] = []
	check(not codec.validate(invalid), "空候选池不能保留待选标记导致继续后卡住")
	run.choose_upgrade("melee", offered[0])
	valid.run_snapshot.run = run.to_dict()
	check(not codec.validate(valid), "已经领取的候选不能同时保留待选标记")
	var profile := Profile.new()
	profile.advance_minor(180)
	profile.major_breakthrough(100, {"foundation_marrow": 1}, true)
	valid = _entry()
	valid.profile = profile.to_dict()
	valid.run_snapshot.qi = 75.0
	check(codec.validate(valid), "筑基档案按实际境界75真气上限校验")

func _test_enemy_armor() -> void:
	var valid := _entry()
	valid.run_snapshot.current_id = "elite"
	valid.run_snapshot.visited["elite"] = true
	valid.run_snapshot.enemies = {"elite:0": 120}
	check(codec.validate(valid), "旧快照不含可选护甲字典仍可恢复")
	valid.run_snapshot["enemy_armor"] = {"elite:0": 0.0}
	check(codec.validate(valid) and codec.validate(JSON.parse_string(JSON.stringify(valid))), "裂甲山魈低血120及破甲0通过，JSON往返不恢复满甲")
	valid.run_snapshot.enemy_armor["elite:0"] = 55.5
	check(codec.validate(valid), "合法护甲允许有限小数并按真实100护甲上限校验")
	for bad in [null, [], "0", {"elite:0": "0"}, {"elite:0": true}, {"elite:0": -0.1}, {"elite:0": 100.1}, {"elite:0": INF}, {"elite:0": NAN}, {"unknown": 0.0}, {"melee:0": 0.0}]:
		var invalid: Dictionary = valid.duplicate(true)
		invalid.run_snapshot.enemy_armor = bad
		check(not codec.validate(invalid), "非法护甲类型、数值或非当前房来源安全拒绝")
