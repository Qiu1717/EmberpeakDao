extends SceneTree
## 检出静态图滑动、错误攻击阶段和逐帧拉伸；使用实际角色与真实图集。
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, text: String) -> bool:
	if not ok:
		push_error("FAIL: " + text)
		quit(1)
		return false
	checks += 1
	print("PASS: " + text)
	return true

func run() -> void:
	var player: Node = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	if not check(player.has_node("ArtworkController"), "主角实际接入动作帧播放器"):
		return
	var visual: Node = player.get_node("ArtworkController")
	visual.set_physics_process(false)
	player.state = player.State.MOVE
	visual.gait_distance = 0
	visual.sync_pose()
	var first: Texture2D = visual.sprite.texture
	var movement_frames: Dictionary = {first: true}
	for step in range(1, 16):
		visual.gait_distance = float(visual.manifest.stride_distance) * step / 16.0
		visual.sync_pose()
		movement_frames[visual.sprite.texture] = true
	if not check(first is AtlasTexture and movement_frames.size() >= 2, "主角移动实际切换不同动作区域"):
		return
	for combo in 3:
		player.combo = combo
		player.state = player.State.ATTACK
		player.action_time = player.stats.attack_windup * 0.5
		visual.sync_pose()
		if not check(visual.animation_name == "attack_windup", "攻击前摇使用独立蓄势姿势"):
			return
		player.action_time = player.stats.attack_windup + player.stats.attack_active * 0.5
		visual.sync_pose()
		if not check(visual.animation_name == "attack_" + str(combo + 1), "有效判定选择第%d段攻击" % (combo + 1)):
			return
		player.action_time = player.stats.attack_windup + player.stats.attack_active + 0.001
		visual.sync_pose()
		if not check(visual.animation_name == "attack_recover", "有效判定结束切换收势"):
			return
	for state in [player.State.JUMP, player.State.DODGE, player.State.HURT, player.State.DEAD]:
		player.state = state
		visual.sync_pose()
		if not check(visual.animation_name == {player.State.JUMP: "jump", player.State.DODGE: "dodge", player.State.HURT: "hurt", player.State.DEAD: "death"}[state], "主角特殊状态选择相应姿势"):
			return
	for clip: String in visual.manifest.clips:
		var elapsed := 0.0
		for entry: Dictionary in visual.manifest.clips[clip]:
			for direction in [-1, 1]:
				visual.show_clip(clip, elapsed + 0.001, direction)
				var source: Dictionary = visual.manifest.poses[entry.pose]
				var foot: Vector2 = visual.sprite.to_global(visual.sprite.offset + Vector2(source.pivot[0], source.pivot[1]) * visual.import_ratio)
				var scale_from_source: float = 56.0 / float(visual.manifest.reference_height)
				if not check(foot.distance_to(player.global_position) < 0.01 and absf(absf(visual.sprite.scale.x) * visual.import_ratio.x - scale_from_source) < 0.001 and absf(visual.sprite.scale.y * visual.import_ratio.y - scale_from_source) < 0.001, "主角各姿势保留源比例与左右脚底"):
					return
			elapsed += float(entry.duration)
	player.free()
	for id in ["corpse", "ghost", "crossbow", "armored_xiao", "mountain_general"]:
		var enemy: Node = load("res://scenes/enemies/enemy.tscn").instantiate()
		enemy.data = load("res://resources/enemies/" + id + ".tres")
		root.add_child(enemy)
		enemy.set_physics_process(false)
		var art: Node = enemy.get_node("Visual")
		art.set_physics_process(false)
		enemy.state = enemy.State.APPROACH
		enemy.velocity.x = 80
		art.gait_distance = 0
		art.sync_pose()
		first = art.sprite.texture
		movement_frames = {first: true}
		for step in range(1, 16):
			art.gait_distance = float(art.manifest.stride_distance) * step / 16.0
			art.sync_pose()
			movement_frames[art.sprite.texture] = true
		if not check(first is AtlasTexture and movement_frames.size() >= 2, id + " 移动姿势真实切片变化"):
			return
		var all_poses_aligned := true
		for clip: String in art.manifest.clips:
			var elapsed := 0.0
			for entry: Dictionary in art.manifest.clips[clip]:
				for direction in [-1, 1]:
					art.show_clip(clip, elapsed + 0.001, direction)
					var pose: Dictionary = art.manifest.poses[entry.pose]
					var foot: Vector2 = art.sprite.to_global(art.sprite.offset + Vector2(pose.pivot[0], pose.pivot[1]) * art.import_ratio)
					var source_scale: float = enemy.data.body_size.y / float(art.manifest.reference_height)
					var expected_direction: int = direction * int(pose.get("native_facing", art.manifest.native_facing))
					all_poses_aligned = all_poses_aligned and foot.distance_to(enemy.global_position) < 0.01 and signf(art.sprite.scale.x) == expected_direction and absf(absf(art.sprite.scale.x) * art.import_ratio.x - source_scale) < 0.001 and absf(art.sprite.scale.y * art.import_ratio.y - source_scale) < 0.001
				elapsed += float(entry.duration)
		if not check(all_poses_aligned, id + " 每个动作保持统一源比例、双向脚底与逐帧原生朝向"):
			return
		for profile in enemy.data.attacks:
			enemy.attack = profile
			var textures: Array[Texture2D] = []
			for state in [enemy.State.TELEGRAPH, enemy.State.ATTACK, enemy.State.RECOVERY]:
				enemy.state = state
				enemy.clock = 0.01
				art.sync_pose()
				textures.append(art.sprite.texture)
			if not check(textures[0] != textures[1] and textures[1] != textures[2], id + ":" + profile.attack_id + " 蓄势/有效/收势分离"):
				return
		if id == "mountain_general":
			enemy.state = enemy.State.PHASE
			enemy.clock = 0.01
			art.sync_pose()
			if not check(art.animation_name == "phase", "Boss转阶段使用独立姿势"):
				return
		enemy.state = enemy.State.DEAD
		enemy.clock = 0
		art.sync_pose()
		first = art.sprite.texture
		enemy.clock = enemy.data.death_duration * 0.9
		art.sync_pose()
		if not check(first != art.sprite.texture and art.animation_name == "death", id + " 死亡实际切换两姿势"):
			return
		enemy.free()
	print("ACTOR_ANIMATION_CHECKS_PASSED=", checks)
	quit()
