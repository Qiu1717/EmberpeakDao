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
func frames(count: int = 3) -> void:
	for index in count:
		await physics_frame
	await process_frame
	await process_frame
func capture(id: String) -> void:
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://builds/all_art")
		RenderingServer.force_draw()
		if root.get_texture().get_image().save_png("res://builds/all_art/" + id + ".png") != OK:
			push_error("FAIL: 无法保存实际视口截图")
			quit(1)
func run() -> void:
	if not check(FileAccess.file_exists("res://assets/art_catalog.json"), "现有美术清单实际存在"):
		return
	var catalog: Script = load("res://scripts/art/art_catalog.gd")
	var entries: Array = catalog.entries()
	if not check(entries.size() == 26, "26张原始素材全部登记"):
		return
	var counts: Dictionary = {}
	var ids: Dictionary = {}
	for entry: Dictionary in entries:
		var texture: Texture2D = load(entry.path)
		if not check(texture != null and texture.get_width() > 0 and not ids.has(entry.id), "真实素材可加载且标识唯一：" + entry.title):
			return
		ids[entry.id] = true
		counts[entry.category] = counts.get(entry.category, 0) + 1
	if not check(counts == {"主角": 1, "敌人": 6, "NPC": 5, "武器装备": 6, "场景": 8}, "素材分类数量与磁盘清点一致"):
		return
	var app: Node = root.get_node("App")
	await app.start_new_game()
	await frames(5)
	var game: Node = current_scene
	var expected := ["sword_entry", "broken_swords", "stepped_corridor", "elite_den", "spirit_altar", "general_hall"]
	for index in 6:
		game.world.enter_room(index)
		await frames(4)
		var background: Node = game.get_node("BackgroundLayer/Backdrop")
		if not check(background.art_id == expected[index] and background.artwork != null, "真实背景随房间切换：" + expected[index]):
			return
		if not check(game.world.room.get_node("Ground/CollisionShape2D").shape.size == Vector2(2200, 120), "背景不改变原物理地面：" + expected[index]):
			return
		for enemy: Node in game.world.room.enemies:
			if not check(enemy.has_node("Visual") and not enemy.show_placeholder_body, "真实敌人有美术表现：" + enemy.data.display_name):
				return
			if enemy.data.enemy_id != "shan_xiao":
				var visual: Node = enemy.get_node("Visual")
				var sprite: Sprite2D = visual.sprite
				if not check(sprite.texture.get_image().get_format() == Image.FORMAT_RGBA8 and sprite.texture.get_image().is_invisible() == false, "敌人使用真实透明静态精灵：" + enemy.data.display_name):
					return
				for direction in [-1, 1]:
					enemy.facing = direction
					visual.sync_pose()
					var pivot: Vector2 = visual.pivot
					if not check(sprite.to_global(sprite.offset + pivot).distance_to(enemy.global_position) < 0.01 and signf(visual.scale.x) == direction * visual.native_facing, "敌人镜像保持脚底：" + enemy.data.enemy_id + str(direction)):
						return
		if index in [1, 3, 5]:
			capture(expected[index])
	await app.start_gallery()
	await frames(4)
	var gallery: Node = current_scene
	var category_menu: OptionButton = gallery.find_child("Category", true, false)
	for category: String in ["主角", "敌人", "NPC", "武器装备", "场景"]:
		var category_index: int = ["全部", "主角", "敌人", "NPC", "武器装备", "场景"].find(category)
		category_menu.select(category_index)
		category_menu.item_selected.emit(category_index)
		await frames()
		if not check(gallery.items.item_count == counts[category], "图鉴分类可浏览：" + category):
			return
		for index in gallery.items.item_count:
			gallery.items.select(index)
			gallery.items.item_selected.emit(index)
			await frames(1)
			if not check(gallery.preview.texture != null and gallery.current_entry.category == category and gallery.caption.text.contains(gallery.current_entry.title), "图鉴显示所选原图：" + gallery.current_entry.title):
				return
		if category in ["NPC", "武器装备", "场景"]:
			capture("gallery_" + str(["NPC", "武器装备", "场景"].find(category)))
	await app.return_to_menu()
	await frames()
	if not check(current_scene.get_node("%Gallery") != null and current_scene.get_node("%Continue").disabled, "图鉴可返回主菜单且不冒充游戏存档"):
		return
	capture("main_menu")
	current_scene.get_node("%Gallery").pressed.emit()
	await scene_changed
	await frames()
	if not check(current_scene.scene_file_path == "res://scenes/art/art_gallery.tscn" and current_scene.items.item_count == 26, "主菜单图鉴按钮实际连接完整图鉴入口"):
		return
	current_scene.get_node("%Back").pressed.emit()
	await scene_changed
	await frames()
	if not check(current_scene.scene_file_path == "res://scenes/main/main_menu.tscn", "图鉴返回按钮实际连接主菜单"):
		return
	print("ALL_ART_CHECKS_PASSED=", checks)
	quit()
