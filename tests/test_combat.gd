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

func key(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)

func _run() -> void:
	if not check(ResourceLoader.exists("res://scenes/player/player.tscn"), "主角场景存在"):
		return
	change_scene_to_file("res://scenes/world/game.tscn")
	await frames(12)
	var arena: Node = current_scene.get_node("World/TrainingArena")
	var player: Node = arena.get_node("Player")
	var target: Node = arena.get_node("Target")
	var original_id: int = player.get_instance_id()
	if not check(player.health == 100 and player.is_on_floor(), "满生命且真实地面检测"):
		return
	var start: Vector2 = player.position
	key("move_right", true)
	await frames(30)
	key("move_right", false)
	if not check(player.position.x > start.x + 80 and player.facing == 1, "移动与加速朝向"):
		return
	key("jump", true)
	await frames(3)
	key("jump", false)
	if not check(player.position.y < start.y - 10 and player.state == player.State.JUMP, "真实输入跳跃与状态"):
		return
	await frames(65)
	if not check(player.is_on_floor(), "重力与落地"):
		return
	player.position = Vector2(650, 470)
	player.velocity = Vector2.ZERO
	await frames(30)
	if not check(player.is_on_floor() and absf(player.position.y - 540) < 2, "平台碰撞站立"):
		return
	player.position = Vector2(300, 640)
	player.velocity = Vector2.ZERO
	await frames(3)
	start = player.position
	key("dodge", true)
	await frames(1)
	key("dodge", false)
	if not check(player.is_invulnerable() and not player.receive_hit(10, Vector2.ZERO), "闪避期间伤害被拒绝"):
		return
	await frames(16)
	if not check(absf(player.position.x - start.x - 150) < 2 and not player.is_invulnerable(), "闪避距离150且0.20秒后无敌结束"):
		return
	if not check(not player.try_dodge(), "闪避冷却阻止连续触发"):
		return
	if not check(player.receive_hit(10, Vector2(-180, -100)) and player.health == 90 and player.state == player.State.HURT, "扣血与受击硬直"):
		return
	if not check(player.velocity.x < 0, "击退方向"):
		return
	await frames(16)
	if not check(player.state != player.State.HURT and current_scene.health_bar.value == 90, "硬直按时结束且HUD显示90生命"):
		return
	player.position = Vector2(300, 640)
	player.velocity = Vector2.ZERO
	player.stats.critical_chance = 0.0
	target.position = Vector2(360, 640)
	await frames(3)
	key("attack", true)
	await frames(1)
	key("attack", false)
	if not check(target.health == 200, "前摇不自动命中"):
		return
	await frames(12)
	if not check(target.health == 186, "有效窗口命中14且每挥击去重"):
		return
	if not check(not player.try_attack(), "攻击冷却与收招限制"):
		return
	await frames(18)
	target.position = Vector2(360, 640)
	target.velocity = Vector2.ZERO
	var hp: int = target.health
	player.try_attack()
	await frames(30)
	if not check(target.health == hp - 18, "第二段连击读取18伤害"):
		return
	hp = target.health
	target.position = player.position + Vector2(60, 0)
	target.velocity = Vector2.ZERO
	player.try_attack()
	await frames(30)
	if not check(target.health == hp - 24, "第三段连击读取24伤害"):
		return
	target.position = Vector2(1100, 640)
	hp = target.health
	player.try_attack()
	await frames(30)
	if not check(target.health == hp, "攻击范围外不命中"):
		return
	var world_motion := InputEventMouseMotion.new()
	world_motion.position = Vector2(600, 400)
	root.push_input(world_motion, true)
	var world_click := InputEventMouseButton.new()
	world_click.position = world_motion.position
	world_click.button_index = MOUSE_BUTTON_LEFT
	world_click.pressed = true
	root.push_input(world_click, true)
	await frames(1)
	world_click.pressed = false
	root.push_input(world_click, true)
	if not check(player.state == player.State.ATTACK, "世界区域鼠标左键能触发攻击"):
		return
	await frames(30)
	var damage = load("res://scripts/combat/damage.gd")
	if not check(damage.resolve(20, 100) == 10 and damage.resolve(20, 0, 1.0, 1.0, 1.5) == 30, "统一防御和暴击公式"):
		return
	player.position = Vector2(1089, 440)
	player.velocity = Vector2.ZERO
	await frames(3)
	player.velocity.x = 280
	player.try_attack()
	await frames(26)
	key("jump", true)
	await frames(2)
	key("jump", false)
	if not check(not player.is_on_floor() and player.velocity.y > 0, "攻击离地后容错过期不能空中再跳"):
		return
	player.position = Vector2(32, 640)
	player.velocity = Vector2.ZERO
	key("move_left", true)
	await frames(30)
	key("move_left", false)
	if not check(player.position.x >= 12 and player.facing == -1, "左边界碰撞与左朝向保持可见"):
		return
	player.position = Vector2(2168, 640)
	player.velocity = Vector2.ZERO
	key("move_right", true)
	await frames(30)
	key("move_right", false)
	if not check(player.position.x <= 2188.1, "右边界与摄像机范围一致"):
		return
	await frames(60)
	var camera: Camera2D = player.get_node("Camera2D")
	if not check(camera.get_screen_center_position().x > 1500 and current_scene.get_node("%Pause").get_global_rect().position.x > 1000, "摄像机实际跟随且HUD保持视口位置"):
		return
	player.receive_hit(1000, Vector2.ZERO)
	if not check(player.health == 0 and player.state == player.State.DEAD, "致死状态与生命下限"):
		return
	start = player.position
	key("move_right", true)
	key("attack", true)
	await frames(15)
	key("move_right", false)
	key("attack", false)
	if not check(absf(player.position.x - start.x) < 1, "死亡禁止移动与攻击"):
		return
	current_scene.get_node("%Restart").pressed.emit()
	await frames(12)
	var fresh: Node = current_scene.get_node("World/TrainingArena/Player")
	if not check(fresh.get_instance_id() != original_id and fresh.health == 100 and fresh.state != fresh.State.DEAD and not paused, "测试重开真实重载并恢复状态"):
		return
	var point: Vector2 = current_scene.get_node("%Pause").get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	await frames(2)
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	if not check(paused and fresh.state != fresh.State.ATTACK, "点击暂停界面不触发武器攻击"):
		return
	root.get_node("App").set_paused(false)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://builds/phase2")
		root.get_texture().get_image().save_png("res://builds/phase2/training.png")
	print("COMBAT_CHECKS_PASSED=", checks)
	quit()
