extends SceneTree
var checks := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("FAIL: " + message)
		quit(1)
		return false
	checks += 1
	print("PASS: " + message)
	return true
func _run() -> void:
	var script: Script = load("res://scripts/roguelite/run_state.gd")
	var first = script.new(817)
	if not check(first.has_method("to_dict") and first.has_method("restore"), "探索状态可序列化与恢复"):
		return
	first.claim_enemy("boss:0", "mountain_general")
	first.claim_chest("chest:1")
	first.resolve_event("monument", "sword_question", "b", 90, 100)
	first.buy("merchant", "talisman", 90, 100)
	var options: Array = first.offer_upgrades("room")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(first.to_dict()))
	var second = script.new(0)
	if not check(second.restore(snapshot), "真实JSON往返恢复所有探索数据"):
		return
	if not check(second.run_id == first.run_id and second.spirit == first.spirit and second.stones == first.stones and second.materials == first.materials and second.equipment_rewards == first.equipment_rewards, "资源与实物实例没有变更"):
		return
	if not check(second.offer_upgrades("room") == options and not second.claim_enemy("boss:0", "mountain_general").accepted and not second.claim_chest("chest:1").accepted and not second.resolve_event("monument", "sword_question", "a", 90, 100).accepted, "读档不重抽、不重发Boss宝箱与事件"):
		return
	if not check(second.use_lethal_guard() and not second.use_lethal_guard(), "继续后替劫符次数真实保留"):
		return
	for index in 20:
		var a: Dictionary = first.claim_enemy("next:" + str(index), "shan_xiao")
		var b: Dictionary = second.claim_enemy("next:" + str(index), "shan_xiao")
		if not check(a == b, "完整RNG状态恢复，后续掉落相同%d" % index):
			return
	for field in ["drop_rng_state", "upgrade_rng_state", "claimed", "shops", "equipment_rewards", "spirit"]:
		var broken: Dictionary = snapshot.duplicate(true)
		broken[field] = "损坏" if not field.ends_with("rng_state") else "9000000000000000000000"
		var before: Dictionary = second.to_dict()
		if not check(not second.restore(broken) and second.to_dict() == before, "坏字段不污染活跃状态：" + field):
			return
	var invalid: Dictionary = snapshot.duplicate(true)
	invalid.upgrades = {"unknown": 1}
	if not check(not second.restore(invalid), "非法强化被拒绝"):
		return
	print("RUN_SNAPSHOT_PASSED=", checks)
	quit()
