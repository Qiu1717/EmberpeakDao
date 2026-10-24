extends SceneTree

var checks := 0
var failures := 0
var profile_script: Script
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
	check(FileAccess.file_exists("res://scripts/progression/profile_state.gd"), "永久成长账本可执行")
	if failures > 0:
		quit(1)
		return
	profile_script = load("res://scripts/progression/profile_state.gd")
	rules = load("res://resources/realms/first_map_realms.tres")
	_test_minor()
	_test_major()
	_test_record()
	_test_restore()
	_test_rules()
	if failures == 0:
		print("PROGRESSION_CHECKS_PASSED=", checks)
	quit(1 if failures else 0)

func _test_minor() -> void:
	var profile = profile_script.new()
	var before: Dictionary = profile.to_dict()
	var low: Dictionary = profile.advance_minor(39)
	check(not low.accepted and low.pending == 39 and low.breakthroughs.is_empty() and profile.to_dict() == before, "灵气不足40时无任何消耗或境界变化")
	var exact: Dictionary = profile.advance_minor(40)
	check(exact.accepted and exact.pending == 0 and exact.breakthroughs == ["炼气中期"] and profile.subrealm == 1, "达到40自动突破中期且扣除本阶段灵气")
	check(profile.stats().max_health == 104 and is_equal_approx(profile.stats().attack_multiplier, 1.02), "小境界实际改变生命与攻击倍率")
	profile = profile_script.new()
	var chain: Dictionary = profile.advance_minor(285)
	check(chain.accepted and chain.pending == 105 and chain.breakthroughs == ["炼气中期", "炼气后期", "炼气圆满"] and profile.realm == 0 and profile.subrealm == 3, "40加60加80连续突破至圆满并保留105溢出，不自动筑基")
	var stop: Dictionary = profile.advance_minor(chain.pending)
	check(not stop.accepted and stop.pending == 105 and profile.realm == 0 and profile.subrealm == 3, "圆满即使灵气充足也等待祭坛手动突破")
	profile = profile_script.new()
	check(profile.record_resources(30, 0, {}), "记录账本例子的30灵气")
	var mixed: Dictionary = profile.advance_minor(25)
	check(mixed.accepted and mixed.pending == 0 and profile.banked_spirit == 15 and profile.subrealm == 1, "已记录30加未记录25突破40：先扣未记录25再扣已记录15")
	var saved: Dictionary = profile.to_dict()
	var restored = profile_script.new()
	check(restored.restore(saved) and restored.banked_spirit == 15 and restored.subrealm == 1, "永久档案恢复不返还已消耗灵气与境界")
	before = profile.to_dict()
	check(not profile.advance_minor(-1).accepted and profile.to_dict() == before, "非法负灵气不污染永久状态")

func _test_major() -> void:
	var profile = profile_script.new()
	profile.advance_minor(180)
	var before: Dictionary = profile.to_dict()
	var pending_materials := {"foundation_marrow": 2, "corpse_iron": 3}
	var outside: Dictionary = profile.major_breakthrough(125, pending_materials, false)
	check(not outside.accepted and not outside.message.is_empty() and outside.pending == 125 and outside.materials == pending_materials and profile.to_dict() == before, "祭坛外不能突破且灵气材料均不扣")
	check(not profile.major_breakthrough(100, {}, true).accepted and profile.to_dict() == before, "缺少筑基灵髓不能突破")
	check(not profile.major_breakthrough(99, pending_materials, true).accepted and profile.to_dict() == before, "大境界灵气不足100不扣材料")
	var success: Dictionary = profile.major_breakthrough(125, pending_materials, true)
	check(success.accepted and success.pending == 25 and success.materials == {"foundation_marrow": 1, "corpse_iron": 3} and pending_materials.foundation_marrow == 2, "祭坛突破扣100及一份材料，保留灵气和材料溢出且不改入参")
	check(profile.realm == 1 and profile.subrealm == 0 and profile.stats().max_health == 115 and is_equal_approx(profile.stats().attack_multiplier, 1.08) and profile.stats().max_qi == 75, "筑基初期获得实际属性且保持技能真气与成长灵气分开")
	before = profile.to_dict()
	check(not profile.advance_minor(10000).accepted and not profile.major_breakthrough(10000, pending_materials, true).accepted and profile.to_dict() == before, "首图配置止于筑基初期，不虚构第二地图成长")
	profile = profile_script.new()
	before = profile.to_dict()
	check(not profile.major_breakthrough(1000, pending_materials, true).accepted and profile.to_dict() == before, "小境界未圆满不能直接跨大境界")
	profile.advance_minor(180)
	profile.record_resources(90, 0, {"foundation_marrow": 1})
	var mixed: Dictionary = profile.major_breakthrough(25, {"foundation_marrow": 1}, true)
	check(mixed.accepted and mixed.pending == 0 and mixed.materials.foundation_marrow == 0 and profile.banked_spirit == 15 and profile.banked_materials.foundation_marrow == 1, "大境界优先扣未记录灵气与材料，保留尚未消耗永久余额")
	profile = profile_script.new()
	profile.advance_minor(180)
	profile.record_resources(100, 0, {"foundation_marrow": 2})
	var banked: Dictionary = profile.major_breakthrough(0, {}, true)
	check(banked.accepted and profile.banked_spirit == 0 and profile.banked_materials.foundation_marrow == 1, "已记录材料也可突破且永久余额同步扣一份")

func _test_record() -> void:
	var profile = profile_script.new()
	var materials := {"foundation_marrow": 1, "spirit_dust": 2}
	check(profile.record_resources(45, 20, materials) and profile.banked_spirit == 45 and profile.banked_stones == 20 and profile.banked_materials == materials and profile.subrealm == 0, "祭坛记录只转入永久余额，不额外突破")
	materials.spirit_dust = 99
	check(profile.banked_materials.spirit_dust == 2, "记录材料不保存可被外部修改的引用")
	var before: Dictionary = profile.to_dict()
	for invalid in [{"unknown": 1}, {"corpse_iron": -1}, {"corpse_iron": 1.5}, {"corpse_iron": true}]:
		check(not profile.record_resources(5, 5, invalid) and profile.to_dict() == before, "非法材料整体拒绝且不转移任何资源")
	check(not profile.record_resources(-1, 5, {}) and not profile.record_resources(5, -1, {}) and profile.to_dict() == before, "负灵气或负灵石记录失败且不污染账本")
	var result: Dictionary = profile.advance_minor(0)
	check(result.accepted and profile.banked_spirit == 5 and profile.subrealm == 1, "已记录灵气仍可消费，突破后不会重复返还")
	var exported: Dictionary = profile.to_dict()
	exported.banked_materials.clear()
	exported.weapon_unlocks.clear()
	check(profile.banked_materials.foundation_marrow == 1 and profile.weapon_unlocks == ["qing_feng"], "导出档案深拷贝，外部变更不能改活跃账本")

func _test_restore() -> void:
	var profile = profile_script.new()
	var valid := {"realm": 0, "subrealm": 2, "banked_spirit": 12, "banked_stones": 8, "banked_materials": {"corpse_iron": 3, "foundation_marrow": 1}, "weapon_unlocks": ["qing_feng", "po_shan"], "blueprints": ["xuan_wen", "hui_ling"], "boss_kills": ["mountain_general"]}
	check(profile.restore(valid) and profile.subrealm == 2 and profile.banked_spirit == 12 and profile.weapon_unlocks == ["qing_feng", "po_shan"], "恢复真实境界、余额、武器解锁、蓝图与Boss进度")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(valid))
	check(typeof(parsed.banked_spirit) == TYPE_FLOAT and profile.restore(parsed) and typeof(profile.to_dict().banked_spirit) == TYPE_INT, "JSON整数浮点接受并规范化为整数")
	var before: Dictionary = profile.to_dict()
	for key in ["realm", "subrealm", "banked_spirit", "banked_stones"]:
		for bad in [true, "1", 1.5, -1, INF, NAN]:
			var invalid: Dictionary = valid.duplicate(true)
			invalid[key] = bad
			check(not profile.restore(invalid) and profile.to_dict() == before, "拒绝字段%s的非法数字且恢复无副作用" % key)
	for change in [{"realm": 2}, {"realm": 1, "subrealm": 1}, {"subrealm": 4}, {"banked_materials": {"unknown": 1}}, {"banked_materials": {"corpse_iron": 0.5}}, {"weapon_unlocks": ["unknown"]}, {"weapon_unlocks": ["qing_feng", "qing_feng"]}, {"blueprints": ["ti_jie"]}, {"boss_kills": ["armored_xiao"]}, {"banked_materials": []}, {"blueprints": {}}, {"weapon_unlocks": "qing_feng"}]:
		var invalid: Dictionary = valid.duplicate(true)
		invalid.merge(change, true)
		check(not profile.restore(invalid) and profile.to_dict() == before, "非法ID、未配置境界与类型整体拒绝")
	for key in valid:
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(key)
		check(not profile.restore(missing) and profile.to_dict() == before, "永久档案必填字段%s不能缺失" % key)
	parsed.banked_materials.corpse_iron = 50
	parsed.blueprints.clear()
	check(profile.banked_materials.corpse_iron == 3 and profile.blueprints == ["xuan_wen", "hui_ling"], "恢复后不继续引用调用方的材料和蓝图")

func _test_rules() -> void:
	check(rules.current(1, 1).is_empty() and rules.next(1, 0).is_empty(), "首图未配置阶段和后继明确返回空字典")
	var stage: Dictionary = rules.current(0, 0)
	stage.max_health = 999
	check(rules.current(0, 0).max_health == 100, "境界属性返回副本，不允许调用方篡改Resource")
	var short_rules: Resource = rules.duplicate(true)
	short_rules.stages.pop_back()
	var profile = profile_script.new(short_rules)
	profile.advance_minor(180)
	var before: Dictionary = profile.to_dict()
	check(not profile.major_breakthrough(100, {"foundation_marrow": 1}, true).accepted and profile.to_dict() == before, "缺少后继配置时禁止大境界突破且不消费资源")
