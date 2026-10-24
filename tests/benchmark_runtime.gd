extends SceneTree
## 图形性能夹具：固定玩家位置／补血以持续观察真实AI，不作为自然通关。
var duration := 300.0
var frame_ms: Array = []
var samples: Array = []
var stage := -1
const ROOMS := ["entry", "melee", "platform", "elite", "boss", "altar", "boss", "melee", "boss", "entry"]

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="):
			duration = clampf(argument.trim_prefix("--seconds=").to_float(), 10, 3600)
	_run.call_deferred()

func frames(count: int = 6) -> void:
	for index in count:
		await process_frame

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("性能采样必须使用实际窗口，不能以headless帧率冒充渲染性能")
		quit(1)
		return
	var app: Node = root.get_node("App")
	await app.start_new_game()
	await frames(20)
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var route: Node = current_scene.world
	var started := Time.get_ticks_usec()
	var previous := started
	var sampled_second := -1
	var last_sample_frame := 0
	var last_sample_time := started
	while (Time.get_ticks_usec() - started) / 1000000.0 < duration:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := (now - started) / 1000000.0
		frame_ms.append((now - previous) / 1000.0)
		previous = now
		var next_stage := mini(ROOMS.size() - 1, floori(elapsed / (duration / ROOMS.size())))
		if next_stage != stage:
			stage = next_stage
			route._load_node(ROOMS[stage], false)
			var x := 650.0
			route.player.reset_motion_at(Vector2(x, route.room.map.floor_at(x)))
			for enemy in route.room.enemies:
				if enemy.data.behavior == "boss":
					enemy.state = enemy.State.IDLE
					enemy.receive_hit(600, Vector2.ZERO)
			print("BENCH_STAGE elapsed=%.1f room=%s" % [elapsed, ROOMS[stage]])
		# 只固定测试目标，敌人／弹体／动画／地图保持真实处理。
		route.player.health = route.player.stats.max_health
		route.player.position = Vector2(650, route.room.map.floor_at(650))
		route.player.velocity = Vector2.ZERO
		if floori(elapsed) != sampled_second:
			sampled_second = floori(elapsed)
			var interval_fps := (frame_ms.size() - last_sample_frame) * 1000000.0 / maxf(1, now - last_sample_time)
			samples.append({"seconds": elapsed, "room": ROOMS[stage], "fps": interval_fps, "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, "nodes": get_node_count(), "orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), "memory_bytes": OS.get_static_memory_usage(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "revision": route.session.saved.get("revision", 0)})
			last_sample_frame = frame_ms.size()
			last_sample_time = now
			if sampled_second % 30 == 0:
				print("BENCH_SAMPLE ", JSON.stringify(samples.back()))
	frame_ms.sort()
	var result := {"engine": Engine.get_version_info().string, "seconds": (Time.get_ticks_usec() - started) / 1000000.0, "frames": frame_ms.size(), "display": DisplayServer.get_name(), "renderer": RenderingServer.get_video_adapter_name(), "driver": RenderingServer.get_current_rendering_driver_name(), "resolution": "1280x720", "fps_cap": 60, "vsync": false, "p50_frame_ms": frame_ms[floori(frame_ms.size() * 0.50)], "p95_frame_ms": frame_ms[floori(frame_ms.size() * 0.95)], "p99_frame_ms": frame_ms[floori(frame_ms.size() * 0.99)], "max_frame_ms": frame_ms.back(), "samples": samples}
	var file := FileAccess.open("res://builds/phase7/benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	result.erase("samples")
	print("BENCHMARK_COMPLETE ", JSON.stringify(result))
	quit()
