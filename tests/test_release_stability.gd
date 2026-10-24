extends SceneTree
var checks := 0
var app: Node
var session: Node

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

func connections() -> Array:
	return [app.state_changed.get_connections().size(), session.changed.get_connections().size(), session.feedback.get_connections().size()]

func _run() -> void:
	app = root.get_node("App")
	session = root.get_node("Session")
	await app.start_new_game()
	await frames(8)
	var route: Node = current_scene.world
	route._load_node("melee", false)
	await frames(4)
	for enemy in route.room.enemies:
		enemy.set_physics_process(false)
	# 故障夹具：已有记录灵气30，首只敌人12可触发小突破；先让磁盘写失败。
	var candidate: RefCounted = session.clone_profile()
	candidate.banked_spirit = 30
	session.commit_state(candidate, route.capture_snapshot())
	var valid_store: RefCounted = session.store
	session.store = load("res://scripts/save/save_file.gd").new("res://project.godot/save.json", load("res://scripts/save/snapshot_codec.gd").validate)
	var dead: Node = route.room.enemies[0]
	dead.state = dead.State.IDLE
	dead.receive_hit(100000, Vector2.ZERO)
	dead.set_physics_process(true)
	await frames(55)
	if not check(not is_instance_valid(dead) and route.room.alive == 1, "部分清场后死亡演出结束，敌人节点实际释放"):
		return
	if not check(session.profile.subrealm == 0 and session.message.contains("保存失败"), "自动突破写失败不发布境界，死亡节点仍及时释放"):
		return
	session.store = valid_store
	current_scene.run_interface.open("inventory", {})
	current_scene.run_interface.get_node("%RetryGrowthSave").pressed.emit()
	if not check(session.profile.subrealm == 1 and session.profile.banked_spirit == 2 and route.run.spirit == 0, "死亡节点释放后真实行囊重试成功，消费准确且不重复发奖"):
		return
	current_scene.run_interface.close()
	var saved: Dictionary = session.commit_state(session.clone_profile(), route.capture_snapshot())
	if not check(saved.accepted, "部分敌人已释放时仍能保存，不因遗漏死亡来源而拒绝合法快照"):
		return
	if not check(session.saved.run_snapshot.enemies.get("melee:0", -1) == 0, "已释放敌人仍记录0生命，不能读档复活或重发奖励"):
		return
	await app.return_to_menu()
	await app.continue_game()
	await frames(8)
	route = current_scene.world
	for enemy in route.room.enemies:
		enemy.set_physics_process(false)
	if not check(route.room.enemies.size() == 1 and session.commit_state(session.clone_profile(), route.capture_snapshot()).accepted, "部分清场读档后再次保存仍保持死亡记录"):
		return
	var living: Node = route.room.enemies[0]
	living.state = living.State.IDLE
	living.attack = living.data.attacks[0]
	living._spawn_projectile(1, false)
	var projectile: Node = route.room.get_child(route.room.get_child_count() - 1)
	living.receive_hit(100000, Vector2.ZERO)
	living.set_physics_process(true)
	await frames(4)
	current_scene.run_interface.close()
	await frames(60)
	if not check(not is_instance_valid(living) and not is_instance_valid(projectile), "敌人死亡后演出节点与其弹体实际清理"):
		return
	var full_save_ms: Array = []
	route._load_node("altar", false)
	await frames(8)
	route.player.position = route.room.altar_point
	for index in 5:
		var started := Time.get_ticks_usec()
		var result: Dictionary = route.altar_action("save")
		full_save_ms.append((Time.get_ticks_usec() - started) / 1000.0)
		if not check(result.accepted, "祭坛真实完整快照提交%d" % index):
			return
	# 预热一次所有公共场景，再比较相同菜单基线；资源缓存不当成泄漏。
	await app.return_to_home()
	await frames(8)
	await app.return_to_menu()
	await frames(8)
	var node_baseline: int = root.get_tree().get_node_count()
	var orphan_baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var signal_baseline := connections()
	var samples: Array = []
	for index in 20:
		await app.start_new_game()
		await frames(6)
		var old_scene: WeakRef = weakref(current_scene)
		route = current_scene.world
		var ui: Node = current_scene.run_interface
		for repeat in 5:
			ui.open("inventory", {})
			ui.close()
		var revision: int = session.saved.revision
		await frames(20)
		if not check(session.saved.revision == revision, "无成长／交易时空闲不重复存档，循环%d" % index):
			return
		await app.return_to_home()
		await frames(6)
		await app.return_to_menu()
		await frames(6)
		var nodes: int = root.get_tree().get_node_count()
		var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		samples.append({"cycle": index, "nodes": nodes, "orphans": orphans, "signals": connections(), "memory_bytes": OS.get_static_memory_usage()})
		if not check(old_scene.get_ref() == null and nodes == node_baseline and orphans == orphan_baseline and connections() == signal_baseline, "切换后旧场景释放，节点／孤儿／信号无累积，循环%d" % index):
			return
	# 同一合法候选连续保存只测同步写盘耗时，不增加新自动保存点。
	var latencies: Array = []
	for index in 10:
		var started := Time.get_ticks_usec()
		var result: Dictionary = session.commit_state(session.clone_profile(), null)
		latencies.append((Time.get_ticks_usec() - started) / 1000.0)
		if not check(result.accepted, "真实磁盘提交可重复完成%d" % index):
			return
	var file := FileAccess.open("res://builds/phase7/stability.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"cycles": samples, "profile_save_ms": latencies, "full_save_ms": full_save_ms, "node_baseline": node_baseline, "orphan_baseline": orphan_baseline, "signal_baseline": signal_baseline}, "\t"))
	file.close()
	print("RELEASE_STABILITY_PASSED=", checks)
	quit()
