extends SceneTree
var checks := 0
func _initialize() -> void:
	run.call_deferred()
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
func capture(id: String) -> void:
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://builds/art_room")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/art_room/" + id + ".png")
func run() -> void:
	if not check(ResourceLoader.exists("res://scripts/art/shan_xiao_visual.gd"), "可试玩山魈表现存在"):
		return
	if not check(ResourceLoader.exists("res://scenes/art/shan_xiao_art_room.tscn"), "独立可玩样板房存在"):
		return
	var app: Node = root.get_node("App")
	change_scene_to_file("res://scenes/art/shan_xiao_art_room.tscn")
	await frames(8)
	var room: Node = current_scene
	var enemy: Node = room.enemy
	var player: Node = room.player
	var visual: Node = enemy.get_node("Visual")
	if not check(enemy.health == 90 and player.health == 100 and enemy.get_node("CollisionShape2D").shape.size == Vector2(32, 56) and app.state == app.State.PLAYING, "直接运行可暂停，真实角色与原碰撞配置保持不变"):
		return
	enemy.set_physics_process(false)
	enemy._set_state(enemy.State.IDLE)
	visual.sync_pose()
	if not check(visual.animation_name == "idle" and visual.sprite.sprite_frames.get_frame_count("idle") == 2, "两张真实待机姿势已载入"):
		return
	var neutral_texture: Texture2D = visual.sprite.sprite_frames.get_frame_texture("idle", 0)
	for facing in [-1, 1]:
		enemy.facing = facing
		visual.sync_pose()
		var ratio: float = neutral_texture.get_width() / 1254.0
		var anchor: Vector2 = visual.sprite.to_global(visual.sprite.offset + Vector2(800, 1205) * ratio)
		if not check(anchor.distance_to(enemy.global_position) < 0.01 and signf(visual.scale.x) == -facing, "左右翻转绕真实脚底根节点：" + str(facing)):
			return
	if not check(is_equal_approx(visual.sprite.scale.y * neutral_texture.get_height() * 1125 / 1254.0, 56), "导入缩图后中立姿势仍为56世界像素高度"):
		return
	await capture("idle")
	enemy.set_physics_process(true)
	player.stats.max_health = 10000
	player.health = 10000
	player.reset_motion_at(Vector2(310, 640))
	enemy.position = Vector2(720, 640)
	enemy._set_state(enemy.State.APPROACH)
	await frames(8)
	var first_frame: int = visual.sprite.frame
	await frames(10)
	if not check(visual.animation_name == "run" and visual.sprite.frame != first_frame and visual.sprite.sprite_frames.get_frame_count("run") == 4, "真实追踪位移推动四姿势跑动循环"):
		return
	await capture("run")
	player.reset_motion_at(Vector2(enemy.position.x - 55, 640))
	for tick in 100:
		await frames(1)
		if enemy.state == enemy.State.TELEGRAPH:
			break
	if not check(enemy.state == enemy.State.TELEGRAPH and visual.animation_name == "telegraph", "真实AI进入扑击前摇画面"):
		return
	var hp_before: int = player.health
	await frames(12)
	if not check(player.health == hp_before and enemy.state == enemy.State.TELEGRAPH, "前摇阶段不提前结算伤害"):
		return
	await capture("telegraph")
	app.set_paused(true)
	var frozen: float = enemy.clock
	var frozen_frame: int = visual.sprite.frame
	await create_timer(0.12).timeout
	if not check(enemy.clock == frozen and visual.sprite.frame == frozen_frame, "暂停同时冻结真实AI与动画"):
		return
	app.set_paused(false)
	var seen_air := false
	for tick in 100:
		await frames(1)
		if enemy.state == enemy.State.ATTACK and not enemy.is_on_floor():
			seen_air = seen_air or visual.animation_name == "airborne"
			if tick % 6 == 0:
				await capture("attack")
		if enemy.state == enemy.State.RECOVERY and enemy.is_on_floor():
			break
	if not check(seen_air and visual.animation_name == "recovery", "空中保持腾空姿势，实际着地后显示收招"):
		return
	if not check(player.health == hp_before - 12, "扑击有效窗口真实扣12生命且单次不重复命中"):
		return
	await capture("recovery")
	player.reset_motion_at(Vector2(920, 540))
	enemy.position = Vector2(1000, 540)
	enemy.velocity = Vector2.ZERO
	enemy.cooldown = 0
	enemy._set_state(enemy.State.APPROACH)
	var platform_air := false
	for tick in 130:
		await frames(1)
		if enemy.state == enemy.State.ATTACK and not enemy.is_on_floor():
			platform_air = platform_air or visual.animation_name == "airborne"
		if enemy.state == enemy.State.RECOVERY and enemy.is_on_floor():
			break
	if not check(platform_air and absf(enemy.position.y - 540) < 1 and visual.animation_name == "recovery", "平台扑击按实际540高度落地并切换收招"):
		return
	await capture("platform")
	player.reset_motion_at(Vector2(650, 640))
	enemy.position = Vector2(720, 640)
	enemy.receive_hit(1, Vector2(-120, -80))
	await frames(1)
	if not check(enemy.state == enemy.State.HURT and visual.animation_name == "hurt", "受击真实打断并切换专用姿势"):
		return
	await capture("hurt")
	await frames(25)
	enemy._begin_attack(enemy.data.attacks[0])
	enemy.receive_hit(1, Vector2.ZERO)
	await frames(1)
	if not check(visual.animation_name == "hurt" and enemy.state == enemy.State.HURT, "前摇被击断后不继续播放扑击"):
		return
	var deaths := [0]
	enemy.died.connect(func(_source: String): deaths[0] += 1)
	enemy.receive_hit(1000, Vector2.ZERO)
	await frames(1)
	if not check(visual.animation_name == "death" and not enemy.receive_hit(1, Vector2.ZERO) and deaths[0] == 1, "真实死亡切换倒下动作且结算仅一次"):
		return
	await frames(17)
	if not check(visual.sprite.frame == 1, "死亡过程显示第二张实际倒地姿势"):
		return
	await capture("death")
	await frames(25)
	if not check(not is_instance_valid(enemy) and room.arena.is_cleared, "死亡生命周期结束后清场并释放实例"):
		return
	var previous_player: int = player.get_instance_id()
	room.get_node("%RestartArt").pressed.emit()
	await frames(8)
	if not check(current_scene.enemy.health == 90 and current_scene.player.health == 100 and current_scene.player.get_instance_id() != previous_player, "重开创建新角色、恢复生命和初始动画"):
		return
	await app.return_to_menu()
	await frames(4)
	if not check(current_scene.has_node("%ArtRoom") and current_scene.get_node("%Continue").disabled, "主菜单提供独立样板入口，继续游戏仍禁用"):
		return
	current_scene.get_node("%ArtRoom").pressed.emit()
	await frames(8)
	if not check(current_scene.scene_file_path == "res://scenes/art/shan_xiao_art_room.tscn" and app.state == app.State.PLAYING, "菜单入口真实进入样板房"):
		return
	await capture("playable")
	current_scene.player.receive_hit(1000, Vector2.ZERO)
	await frames(2)
	if not check(current_scene.player.health == 0 and current_scene.player.state == current_scene.player.State.DEAD, "玩家死亡后仍可使用样板房重开入口"):
		return
	current_scene.get_node("%RestartArt").pressed.emit()
	await frames(8)
	if not check(current_scene.player.health == 100 and current_scene.enemy.health == 90 and not paused, "死亡后点击重新挑战恢复完整房间"):
		return
	print("ART_ROOM_CHECKS_PASSED=", checks)
	quit()
