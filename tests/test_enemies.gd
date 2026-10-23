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
func frames(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame
func _run() -> void:
	if not check(ResourceLoader.exists("res://resources/enemies/shan_xiao.tres"), "敌人数值资源存在"):
		return
	change_scene_to_file("res://scenes/world/training_game.tscn")
	await frames(12)
	var arena: Node = current_scene.get_node("World/TrainingArena")
	var player: Node = arena.get_node("Player")
	player.stats.max_health = 10000
	player.health = 10000
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy.tscn")
	var ids := ["shan_xiao", "corpse", "ghost", "crossbow", "armored_xiao", "mountain_general"]
	var hp := [90, 75, 58, 65, 420, 1100]
	for index in ids.size():
		var enemy: Node = enemy_scene.instantiate()
		enemy.data = load("res://resources/enemies/" + ids[index] + ".tres")
		enemy.source_id = "test:" + ids[index]
		enemy.position = Vector2(1200, 640)
		arena.add_child(enemy)
		if not check(enemy.health == hp[index] and enemy.data.concept_texture != null, ids[index] + " 生命与概念图配置正确"):
			return
		player.position = Vector2(690, 640)
		player.velocity = Vector2.ZERO
		var start: float = enemy.position.x
		enemy.activate(player)
		await frames(100)
		if enemy.position.x >= start - 5:
			print("TRACE_MOVE ", ids[index], " pos=", enemy.position, " target=", player.position, " state=", enemy.state, " health=", player.health, " sight=", enemy._has_sight())
		if not check(enemy.position.x < start - 5, ids[index] + " 激活感知并实际追踪移动"):
			return
		player.position = enemy.position - Vector2(55, 0)
		player.velocity = Vector2.ZERO
		var before: int = player.health
		var seen: Array[int] = []
		enemy.state_changed.connect(func(value: int): seen.append(value))
		for tick in 420:
			await frames(1)
			if player.health < before and enemy.state == enemy.State.RECOVERY:
				break
		if not check(player.health < before and seen.has(enemy.State.TELEGRAPH) and seen.has(enemy.State.ATTACK) and seen.has(enemy.State.RECOVERY), ids[index] + " 真实预警攻击扣血及反击收招"):
			return
		var old_health: int = enemy.health
		enemy.receive_hit(14, Vector2(-80, -60))
		if not check(enemy.health < old_health and enemy.velocity.x < 0 and enemy.state == enemy.State.HURT, ids[index] + " 受伤硬直与击退"):
			return
		var settlements := [0, 0]
		enemy.died.connect(func(_id: String): settlements[0] += 1)
		enemy.reward_requested.connect(func(_payload: Dictionary): settlements[1] += 1)
		enemy.receive_hit(100000, Vector2.ZERO)
		enemy.receive_hit(100000, Vector2.ZERO)
		if not check(enemy.health == 0 and enemy.state == enemy.State.DEAD and enemy.collision_layer == 0 and settlements == [1, 1], ids[index] + " 死亡碰撞关闭且只结算一次"):
			return
		before = player.health
		await frames(45)
		if not check(player.health == before, ids[index] + " 死亡后无延迟伤害"):
			return
	# 单独验证精英护甲及Boss阈值，不把伤害注入当作自然通关。
	var elite: Node = enemy_scene.instantiate()
	elite.data = load("res://resources/enemies/armored_xiao.tres")
	elite.position = Vector2(700, 640)
	arena.add_child(elite)
	elite.activate(player)
	elite.receive_hit(100, Vector2.ZERO)
	if not check(elite.health == 345, "精英完整甲减伤25%"):
		return
	elite.receive_hit(1, Vector2.ZERO, elite.data.armor_points)
	if not check(elite.armor == 0 and elite.state == elite.State.HURT, "破甲接口清甲并触发硬直"):
		return
	elite.receive_hit(94, Vector2.ZERO)
	if not check(elite.phase == 2, "精英60%阈值解锁砸地"):
		return
	elite.queue_free()
	var boss: Node = enemy_scene.instantiate()
	boss.data = load("res://resources/enemies/mountain_general.tres")
	boss.source_id = "boss:test"
	boss.position = Vector2(700, 640)
	arena.add_child(boss)
	boss.activate(player)
	if not check(boss.state == boss.State.INTRO, "Boss真实入场演出状态"):
		return
	await frames(70)
	boss.receive_hit(495, Vector2.ZERO)
	if not check(boss.health == 605 and boss.phase == 2 and boss.state == boss.State.PHASE, "Boss55%精确阈值与转阶段"):
		return
	await frames(70)
	player.position = boss.position - Vector2(80, 0)
	player.velocity = Vector2.ZERO
	var patterns: Array[String] = []
	boss.attack_started.connect(func(id: String): patterns.append(id))
	for tick in 1800:
		await frames(1)
		# 将测试目标留在攻击感知区域，生命上限只改测试实例。
		if player.position.distance_to(boss.position) > 260:
			player.position = boss.position - Vector2(90, 0)
			player.velocity = Vector2.ZERO
		if patterns.has("slash") and patterns.has("charge") and patterns.has("leap") and patterns.has("double_slash") and patterns.has("wave"):
			break
	if not check(patterns.has("slash") and patterns.has("charge") and patterns.has("leap") and patterns.has("double_slash") and patterns.has("wave"), "Boss自然AI循环五种模式且二阶段含连击冲击波"):
		return
	boss.receive_hit(100000, Vector2.ZERO)
	await frames(45)
	var shooter: Node = enemy_scene.instantiate()
	shooter.data = load("res://resources/enemies/crossbow.tres")
	shooter.position = Vector2(350, 640)
	arena.add_child(shooter)
	shooter.activate(player)
	shooter.set_physics_process(false)
	shooter.attack = shooter.data.attacks[0]
	player.reset_motion_at(Vector2(300, 640))
	player.dodge_remaining = 0
	player.facing = 1
	var health_before: int = player.health
	player.try_dodge()
	shooter._spawn_projectile(-1, false)
	await frames(18)
	if not check(player.health == health_before, "真实弩箭命中闪避无敌时不扣血"):
		return
	player.reset_motion_at(Vector2(300, 640))
	shooter.position.x = 700
	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 100)
	collider.shape = shape
	wall.position = Vector2(500, 600)
	wall.add_child(collider)
	arena.add_child(wall)
	await frames(2)
	shooter._spawn_projectile(-1, false)
	var bolt: Node = arena.get_child(-1)
	var bolt_position: Vector2 = bolt.position
	paused = true
	await frames(8)
	if not check(bolt.position == bolt_position, "暂停实际冻结敌人弹体"):
		return
	paused = false
	await frames(60)
	if not check(not is_instance_valid(bolt) and player.health == health_before, "弩箭扫射线受墙体阻挡不能穿墙伤人"):
		return
	wall.queue_free()
	shooter.position.x = 360
	player.reset_motion_at(Vector2(300, 640))
	await frames(3)
	var jump := InputEventAction.new()
	jump.action = "jump"
	jump.pressed = true
	Input.parse_input_event(jump)
	await frames(3)
	jump.pressed = false
	Input.parse_input_event(jump)
	shooter._spawn_projectile(-1, true)
	await frames(20)
	if not check(player.position.y < 620 and player.health == health_before, "实际跳跃能够越过地面冲击波"):
		return
	shooter.queue_free()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/phase3/enemies.png")
	print("ENEMY_CHECKS_PASSED=", checks)
	quit()
