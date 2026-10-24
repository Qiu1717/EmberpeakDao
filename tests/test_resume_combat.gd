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

func frames(count: int = 4) -> void:
	for index in count:
		await physics_frame
	await process_frame

func freeze(route: Node) -> void:
	route.player.set_physics_process(false)
	for enemy in route.room.enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)

func resume(app: Node) -> Node:
	await app.return_to_menu()
	await frames(2)
	await app.continue_game()
	var route: Node = current_scene.world
	freeze(route)
	await frames(2)
	return route

func _run() -> void:
	var path := OS.get_environment("EMBERPEAK_SAVE_PATH")
	if not check(path.begins_with("user://phase5_resume_combat_") and not FileAccess.file_exists(path), "继续回归使用独立首次无档路径，隔离用户正式存档"):
		return
	var app: Node = root.get_node("App")
	var session: Node = root.get_node("Session")
	await app.start_new_game()
	var route: Node = current_scene.world
	freeze(route)
	await frames(3)
	if not check(route.travel_to("melee"), "真实入口连接可进入近战房"):
		return
	freeze(route)
	var first: Node = route.room.enemies[0]
	var remaining: Node = route.room.enemies[1]
	if not check(first.receive_hit(100000, Vector2.ZERO) and remaining.receive_hit(20, Vector2.ZERO), "真实伤害杀死第一敌人并使另一敌人剩55生命"):
		return
	route.player.health = 73
	route.player.qi = 12.5
	var offers: Array = route.run.offer_upgrades("fixture:cached")
	route.run.claim_enemy("fixture:growth", "armored_xiao")
	await frames(4)
	if not check(session.profile.subrealm == 1 and session.can_continue(), "实际奖励跨40灵气门槛触发自动突破与一致快照保存"):
		return
	var saved: Dictionary = session.saved.run_snapshot.duplicate(true)
	if not check(saved.enemies.get("melee:0") == 0 and saved.enemies.get("melee:1") == 55 and saved.health == 77, "已保存死亡源0、剩敌55及突破后的玩家77生命"):
		return
	route = await resume(app)
	if not check(route.current_id == "melee" and route.room.enemies.size() == 1 and route.room.enemies[0].source_id == "melee:1" and route.room.enemies[0].health == 55, "实际继续只恢复未死敌人及原剩余生命"):
		return
	if not check(route.player.health == 77 and is_equal_approx(route.player.qi, 12.5), "继续恢复玩家已保存生命真气，不额外补血"):
		return
	var run_data: Dictionary = route.run.to_dict()
	if not check(run_data.seed == saved.run.seed and run_data.drop_rng_state == saved.run.drop_rng_state and run_data.upgrade_rng_state == saved.run.upgrade_rng_state and route.run.offer_upgrades("fixture:cached") == offers, "种子、两条RNG状态和已缓存候选精确恢复，不重抽"):
		return
	var spirit: int = route.run.spirit
	if not check(not route.run.claim_enemy("melee:0", "shan_xiao").accepted and route.run.spirit == spirit, "继续后已死来源不能重复领取奖励"):
		return
	# 以下使用真实房间与保存流程的安全点夹具，不代表自然通过路线或击败Boss。
	route._load_node("elite", false)
	freeze(route)
	var elite: Node = route.room.enemies[0]
	elite.health = 120
	elite.armor = 0.0
	elite.phase = 2
	if not check(session.commit_state(session.clone_profile(), route.capture_snapshot()).accepted, "精英低血破甲状态可通过真实存档事务提交"):
		return
	route = await resume(app)
	var restored_elite: Node = route.room.enemies[0]
	if not check(restored_elite.health == 120 and restored_elite.armor == 0.0 and restored_elite.phase == 2, "精英继续准确恢复120生命、0护甲和第二阶段，不重复结算护甲减伤"):
		return
	if not check(route.player.health == 77, "精英安全点继续不改变玩家生命"):
		return
	route._load_node("boss", false)
	freeze(route)
	var boss: Node = route.room.enemies[0]
	boss.health = 500
	boss.armor = 0.0
	boss.phase = 2
	if not check(session.commit_state(session.clone_profile(), route.capture_snapshot()).accepted, "Boss低于55%阈值的安全点状态可真实保存"):
		return
	route = await resume(app)
	var restored_boss: Node = route.room.enemies[0]
	if not check(restored_boss.health == 500 and restored_boss.phase == 2 and restored_boss.armor == 0.0, "Boss继续绕过入场受击限制，准确恢复500生命与第二阶段"):
		return
	if not check(route.player.health == 77 and route.run.to_dict().claimed.has("enemy:melee:0"), "跨房间继续仍保留玩家生命和已死来源去重"):
		return
	print("RESUME_COMBAT_CHECKS_PASSED=", checks)
	quit()
