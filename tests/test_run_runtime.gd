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
func select(run: RefCounted, id: String) -> bool:
	for index in 100:
		var source := "runtime:%s:%d" % [id, index]
		if id in run.offer_upgrades(source):
			return run.choose_upgrade(source, id)
	return false
func _run() -> void:
	await root.get_node("App").start_new_game()
	await frames(16)
	var route: Node = current_scene.world
	var player: Node = route.player
	var run: RefCounted = route.run
	# 规则接入测试：直接请求规则奖励，以隔离随机探索过程。
	for id in ["attack", "health", "defense", "crit", "dodge", "haste"]:
		if not check(select(run, id), "实际应用强化：" + id):
			return
	if not check(player.stats.max_health == 110 and player.health == 110 and player.stats.defense == 3 and is_equal_approx(player.stats.critical_chance, 0.09) and is_equal_approx(player.stats.dodge_cooldown, 0.644) and is_equal_approx(player.stats.attack_duration, 0.42 / 1.05), "六类强化接入生命、防御、暴击、闪避和动作时长"):
		return
	player.health = 70
	for index in 5:
		run.changed.emit()
	if not check(player.health == 70 and is_equal_approx(player.stats.sword_damage[0], 14 * 1.05) and player.stats.max_health == 110, "重复刷新不重复加属性或免费回血"):
		return
	player.health = 110
	player.receive_hit(100, Vector2.ZERO)
	if not check(player.health == 13, "防御加成通过真实受伤公式将100伤害结算为97"):
		return
	await frames(16)
	var target := CharacterBody2D.new()
	target.set_script(load("res://scripts/world/training_target.gd"))
	target.collision_layer = 4
	target.collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 60)
	collision.shape = shape
	collision.position.y = -30
	target.add_child(collision)
	route.room.add_child(target)
	player.reset_motion_at(Vector2(300, route.room.map.floor_at(300)))
	player.facing = 1
	player.stats.critical_chance = 0
	target.position = player.position + Vector2(60, 0)
	await frames(4)
	player.try_attack()
	await frames(15)
	if not check(target.health == 185, "强化后的真实攻击命中15伤害，沿用一次命中去重"):
		return
	await frames(20)
	var reward: Dictionary = run.claim_enemy("runtime:boss", "mountain_general")
	if not check(reward.message.contains("筑基灵髓") and reward.message.contains("破山长枪"), "拾取反馈显示实际材料和装备名称"):
		return
	if not check(run.buy("runtime:shop", "talisman", player.health, player.stats.max_health).accepted, "规则购买替劫符后接入真实角色"):
		return
	player.receive_hit(10000, Vector2.ZERO)
	if not check(player.health == 1 and player.state == player.State.HURT and not run.ended, "替劫符真实阻止一次死亡并保留1生命"):
		return
	player.receive_hit(10000, Vector2.ZERO)
	await frames(50)
	if not check(player.health == 0 and player.state == player.State.DEAD and run.ended, "下一次致死实际死亡，符已消耗"):
		return
	if not check(player.stats.max_health == 100 and player.stats.defense == 0 and player.stats.attack_duration == route.base_stats.attack_duration and current_scene.run_interface.kind == "death", "死亡恢复基准属性并进入探索总结"):
		return
	print("RUN_RUNTIME_PASSED=", checks)
	quit()
