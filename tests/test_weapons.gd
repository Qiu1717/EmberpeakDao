extends SceneTree

var checks := 0
var player: Node
var target: Node
var arena: Node

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

func reset_target(distance: float = 60.0) -> void:
	player.reset_motion_at(Vector2(300, 640))
	player.facing = 1
	player.stats.critical_chance = 0.0
	player.stats.realm_multiplier = 1.0
	target.position = player.position + Vector2(distance, 0)
	target.velocity = Vector2.ZERO
	target.health = 200

func _run() -> void:
	change_scene_to_file("res://scenes/world/training_game.tscn")
	await frames(12)
	arena = current_scene.get_node("World/TrainingArena")
	player = arena.get_node("Player")
	target = arena.get_node("Target")
	if not check(player.has_method("apply_weapon") and player.has_method("try_heavy_attack") and player.has_method("spend_qi"), "主角具有真实换武器、重击和真气消耗接口"):
		return
	target.set_physics_process(false)
	if not check(player.weapon_id == "qing_feng" and is_equal_approx(player.qi, 60.0), "旧训练默认持剑且真气初始化为实际满值60"):
		return
	player.apply_weapon("qing_feng")
	reset_target()
	await frames(2)
	player.try_attack()
	await frames(28)
	if not check(target.health == 186 and player.state != player.State.ATTACK and player.try_attack(), "剑真实命中14且0.42秒收招后可再次攻击"):
		return
	player.apply_weapon("po_shan")
	reset_target()
	await frames(2)
	player.try_attack()
	await frames(28)
	if not check(target.health == 178 and player.state == player.State.ATTACK and not player.try_attack(), "枪真实命中22且同一时刻仍在0.62秒收招中"):
		return
	await frames(14)
	if not check(player.state != player.State.ATTACK and player.try_attack(), "枪收招完成后允许下一次攻击"):
		return
	for item_id in ["qing_feng", "po_shan"]:
		player.apply_weapon(item_id)
		reset_target(150.0)
		await frames(2)
		player.try_attack()
		await frames(42)
		if not check(target.health == (200 if item_id == "qing_feng" else 178), "真实范围150距离：" + item_id + ("无法命中" if item_id == "qing_feng" else "可命中")):
			return
	player.apply_weapon("qing_feng")
	reset_target()
	player.stats.third_attack_multiplier = 1.10
	await frames(2)
	for index in 3:
		player.try_attack()
		await frames(28)
	if not check(target.health == 142, "残剑坠只把实际第三段24提高到26，前两段仍14和18"):
		return
	player.stats.third_attack_multiplier = 1.0
	if not await _test_heavy():
		return
	player.apply_weapon("po_shan")
	reset_target()
	await frames(2)
	player.try_attack()
	player.apply_weapon("")
	await frames(48)
	if not check(not player.try_attack() and not player.try_heavy_attack() and target.health == 200 and player.weapon_id.is_empty(), "卸下武器立即停止本次攻击并禁止普攻和重击"):
		return
	if not check(not player.apply_weapon("unknown") and player.weapon_id.is_empty(), "未知武器ID不会生成默认武器或修改持有状态"):
		return
	player.set_physics_process(false)
	player.qi = 60.0
	if not check(player.spend_qi(20.0) and player.qi == 40.0 and not player.spend_qi(41.0) and player.qi == 40.0 and not player.spend_qi(-1.0), "真气真实扣除，余额不足或非法支出不修改余额"):
		return
	player.qi = 10.0
	player.stats.qi_regen = 4.0
	player._physics_process(0.5)
	player._physics_process(0.5)
	if not check(is_equal_approx(player.qi, 14.0), "真实物理更新每秒恢复4点真气"):
		return
	player.qi = 10.0
	player.stats.qi_regen = 4.6
	player._physics_process(0.5)
	player._physics_process(0.5)
	if not check(is_equal_approx(player.qi, 14.6), "回灵玉佩加成后真实物理更新每秒恢复4.6点真气"):
		return
	player.qi = 59.5
	player._physics_process(1.0)
	if not check(is_equal_approx(player.qi, 60.0), "真气恢复不超过真实上限"):
		return
	player.qi = 10.0
	player.state = player.State.DEAD
	player._physics_process(1.0)
	if not check(is_equal_approx(player.qi, 10.0) and not player.spend_qi(1.0), "死亡后停止真气恢复和消耗"):
		return
	print("WEAPON_CHECKS_PASSED=", checks)
	quit()

func _test_heavy() -> bool:
	var enemy: Node = load("res://scenes/enemies/enemy.tscn").instantiate()
	enemy.data = load("res://resources/enemies/armored_xiao.tres")
	enemy.position = Vector2(360, 640)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	for item_id in ["qing_feng", "po_shan"]:
		player.apply_weapon(item_id)
		reset_target(700.0)
		enemy.health = 420
		enemy.armor = 100.0
		enemy.state = enemy.State.IDLE
		await frames(2)
		var event := InputEventAction.new()
		event.action = "heavy_attack"
		event.pressed = true
		Input.parse_input_event(event)
		await frames(1)
		event.pressed = false
		Input.parse_input_event(event)
		if not check(player.state == player.State.ATTACK and player.heavy_attack, "现有K重击输入真实启动动作：" + item_id):
			return false
		await frames(10)
		if not check(enemy.health == 420 and enemy.armor == 100.0 and player.get_node("ArtworkController").animation_name == "attack_windup", "重击前摇未命中且画面保持蓄势：" + item_id):
			return false
		await frames(16)
		if not check(enemy.armor == (80.0 if item_id == "qing_feng" else 55.0) and enemy.health == (404 if item_id == "qing_feng" else 394), "重击通过现有敌人API一次扣血削甲：" + item_id):
			return false
		await frames(40)
		if not check(player.state != player.State.ATTACK and enemy.armor == (80.0 if item_id == "qing_feng" else 55.0), "重击收招结束且整次动作不重复削甲：" + item_id):
			return false
	player.apply_weapon("po_shan")
	reset_target(700.0)
	enemy.state = enemy.State.IDLE
	enemy.armor = 40.0
	await frames(2)
	player.try_heavy_attack()
	await frames(30)
	if not check(enemy.armor == 0.0 and enemy.state == enemy.State.HURT and is_equal_approx(enemy.hurt_duration, 0.65), "长枪45削甲真实击破剩余40护甲并进入现有破甲硬直"):
		return false
	var visual: Node = player.get_node("ArtworkController")
	player.set_physics_process(false)
	player.action_time = 0.20
	visual.sync_pose()
	if not check(visual.animation_name == "attack_windup", "重击候选帧按本次0.34秒前摇而非普攻0.18秒选择"):
		return false
	player.action_time = 0.40
	visual.sync_pose()
	if not check(visual.animation_name == "attack_1", "重击候选帧在本次有效窗口内同步判定"):
		return false
	player.set_physics_process(true)
	player.reset_motion_at(Vector2(300, 640))
	enemy.queue_free()
	await frames(2)
	return true
