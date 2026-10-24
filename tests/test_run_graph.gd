extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	return ok

func frames(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame

func reachable(nodes: Dictionary, start: String, excluded: String = "") -> Dictionary:
	var seen := {}
	var pending: Array = [start]
	while not pending.is_empty():
		var id: String = pending.pop_back()
		if id == excluded or seen.has(id):
			continue
		seen[id] = true
		pending.append_array(nodes[id].next)
	return seen

func _test_graphs() -> void:
	if not check(ResourceLoader.exists("res://scripts/roguelite/run_graph.gd"), "探索图生成器存在"):
		return
	var graph_script: Script = load("res://scripts/roguelite/run_graph.gd")
	var graph = graph_script.new()
	var replay = graph_script.new()
	var signatures := {}
	var topologies := {}
	var first_side_kinds := {}
	for seed_value in range(1, 101):
		graph.generate(seed_value)
		replay.generate(seed_value)
		var nodes: Dictionary = graph.nodes
		check(graph.seed == seed_value and nodes == replay.nodes, "种子%d重建完全一致" % seed_value)
		if not check(nodes.size() == 10 and nodes.has_all(["entry", "melee", "platform", "monument", "archer", "side_before", "side_after", "elite", "altar", "boss"]), "种子%d生成十个预期节点" % seed_value):
			return
		check(reachable(nodes, "entry").size() == 10, "种子%d入口可达全部节点" % seed_value)
		var templates := {}
		var edges := {}
		for id in nodes:
			var node: Dictionary = nodes[id]
			check(node.has_all(["id", "kind", "template_id", "scene_path", "label", "next", "previous"]) and node.id == id, "节点契约完整")
			check(ResourceLoader.exists(node.scene_path), "路线节点指向可加载房间场景")
			templates[node.template_id] = true
			edges[id] = node.next
			check(reachable(nodes, id).has("boss"), "节点%s具有Boss前进路径" % id)
			check(id == "boss" or not node.next.is_empty(), "非终点没有死路")
			for next_id in node.next:
				check(nodes.has(next_id) and nodes[next_id].previous.has(id), "前进边有对应回退边")
				check(not reachable(nodes, next_id).has(id), "前进路线没有环")
			for previous_id in node.previous:
				check(nodes.has(previous_id) and nodes[previous_id].next.has(id), "回退边指向真实前驱")
		check(templates.size() == 8, "十节点仅用八个手工模板")
		check(not reachable(nodes, "entry", "elite").has("boss"), "精英不可绕过")
		check(not reachable(nodes, "entry", "altar").has("boss"), "祭坛不可绕过")
		check(nodes.boss.previous == ["altar"] and nodes.altar.previous == ["elite"], "Boss可返回原祭坛且关键节点固定")
		check(nodes.entry.next.has("melee") and nodes.entry.next.has("platform") and nodes.melee.next.has("monument") and nodes.platform.next.has("monument"), "入口双战斗分支汇入旧碑")
		check([nodes.side_before.kind, nodes.side_after.kind].has("reward") and [nodes.side_before.kind, nodes.side_after.kind].has("shop"), "两侧支路各有奖励和商店")
		for side in ["side_before", "side_after"]:
			check(nodes[side].template_id == ("sword_entry" if nodes[side].kind == "reward" else "old_monument"), "奖励商店复用已有模板")
		signatures[JSON.stringify(nodes)] = true
		topologies[JSON.stringify(edges)] = true
		first_side_kinds[nodes.side_before.kind] = true
	check(signatures.size() > 1 and topologies.size() > 1 and first_side_kinds.size() == 2, "百种种子同时改变连边和商店奖励位置")
	print("RUN_GRAPH_SEEDS=100 VARIANTS=", signatures.size(), " TOPOLOGIES=", topologies.size())

func _test_room(path: String, expected_heights: Array, expected_enemies: int) -> void:
	if not check(ResourceLoader.exists(path), "新增房间场景存在：" + path):
		return
	var room: Node = load(path).instantiate()
	root.add_child(room)
	var player: Node = load("res://scenes/player/player.tscn").instantiate()
	room.add_child(player)
	player.reset_motion_at(room.entry_point)
	room.enter(player, false)
	await frames(20)
	check(player.is_on_floor() and player.position.distance_to(room.entry_point) < 3, "新增房间出生点真实落地")
	check(room.enemies.size() == expected_enemies, "新增房间敌人数量正确")
	for enemy in room.enemies:
		check(enemy.data.enemy_id == "crossbow" and enemy.is_on_floor(), "弩室真实生成落地的灵弩傀儡")
		enemy.set_physics_process(false)
	# 物理射线期望取自目视原图采样，不调用被测 floor_at 推导。
	var xs := [140.0, 650.0, 950.0, 1400.0]
	for index in xs.size():
		var query := PhysicsRayQueryParameters2D.create(Vector2(xs[index], 580), Vector2(xs[index], 760), 1)
		var hit: Dictionary = room.get_world_2d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y - expected_heights[index]) < 3, "前景原图采样点有贴合的实体碰撞")
	var art: Polygon2D = room.map.get_node("Gameplay0")
	check(art.polygon == art.uv and room.map.get_node("Ground0/CollisionPolygon2D").polygon == art.polygon, "可走原图与物理多边形共用像素轮廓")
	Input.action_press("move_right")
	await frames(230)
	Input.action_release("move_right")
	await frames(20)
	check(player.is_on_floor() and player.position.x > 1200 and player.health > 0, "真实玩家从入口行走穿过新增地形")
	player.reset_motion_at(room.exit_point)
	await frames(15)
	check(player.is_on_floor() and player.position.distance_to(room.exit_point) < 3, "回访出生点真实落地")
	room.free()
	await frames(2)

func _run() -> void:
	_test_graphs()
	await _test_room("res://scenes/rooms/old_monument.tscn", [656.0, 656.0, 656.0, 660.0], 0)
	await _test_room("res://scenes/rooms/archer_sanctum.tscn", [652.0, 683.0, 690.0, 700.0], 2)
	if failures == 0:
		print("RUN_GRAPH_CHECKS_PASSED=", checks)
	quit(1 if failures > 0 else 0)
