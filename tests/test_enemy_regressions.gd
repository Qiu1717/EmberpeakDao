extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func frames(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame
func _run() -> void:
	# 固定平台回归使用独立物理夹具；正式Boss房现为1672宽原图，不能再用旧1700坐标。
	var room: Node = Node2D.new()
	room.set_script(load("res://scripts/world/combat_room.gd"))
	room.room_id = "platform_regression"
	room.platforms.assign([Rect2(400, 540, 200, 24), Rect2(1600, 540, 200, 24)])
	room.enemy_data.assign([load("res://resources/enemies/mountain_general.tres")])
	room.enemy_positions = PackedVector2Array([Vector2(1150, 640)])
	root.add_child(room)
	current_scene = room
	await frames(2)
	var player: Node = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(1700, 640)
	room.add_child(player)
	player.stats.max_health = 10000
	player.health = 10000
	room.enter(player, false)
	await frames(70)
	var boss: Node = room.enemies[0]
	boss.position = Vector2(1300, 640)
	boss.velocity = Vector2.ZERO
	player.reset_motion_at(Vector2(1700, 640))
	boss._begin_attack(boss.data.attacks[2])
	var warning: Vector2 = boss.aimed_position
	for tick in 150:
		await frames(1)
		if boss.impact_done:
			break
	print("LEAP_WARNING=", warning, " IMPACT=", boss.position, " VELOCITY=", boss.velocity)
	check(boss.impact_done and boss.position.distance_to(warning) < 12, "Boss跳砸首次实际落点与平台预警一致")
	check(absf(boss.velocity.x) < 1, "Boss落地立即停止水平滑动")
	await frames(120)
	check(boss.position.y > 620, "Boss落上平台后仍能下落追踪地面玩家")
	boss.queue_free()
	await frames(3)
	var archer: Node = load("res://scenes/enemies/enemy.tscn").instantiate()
	archer.data = load("res://resources/enemies/crossbow.tres")
	archer.position = Vector2(1100, 640)
	room.add_child(archer)
	player.reset_motion_at(Vector2(1000, 640))
	archer.activate(player)
	archer._set_state(archer.State.APPROACH)
	archer.cooldown = 0.5
	await frames(20)
	check(archer.position.x > 1120, "灵弩在冷却中实际后撤保持距离")
	archer._begin_attack(archer.data.attacks[0])
	for tick in 240:
		await frames(1)
		if archer.state == archer.State.RECOVERY:
			break
	for tick in 180:
		await frames(1)
		if archer.state == archer.State.APPROACH:
			break
	check(archer.cooldown > 0.5, "收招结束后仍保留配置的额外冷却")
	await frames(10)
	check(archer.state == archer.State.APPROACH, "额外冷却内不能再次进入射击预警")
	if failures == 0:
		print("ENEMY_REGRESSIONS_PASSED=", checks)
	quit(1 if failures > 0 else 0)
