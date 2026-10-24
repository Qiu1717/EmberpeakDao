extends SceneTree
## 必须通过--main-pack从资源包运行，不能用源码目录的资源掩盖漏打包。
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
func frames(count: int = 6) -> void:
	for index in count:
		await process_frame
func _run() -> void:
	if not check(not ResourceLoader.exists("res://tests/test_framework.gd") and not FileAccess.file_exists("res://docs/GAME_DEVELOPMENT_PLAN.md") and not FileAccess.file_exists("res://scripts/tools/build_windows.ps1"), "实际包不包含测试、方案文档或构建脚本"):
		return
	if not check(extra_jsons("res://assets").is_empty(), "实际包不包含生成请求、内部来源和QA记录JSON"):
		return
	if not check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main/main_menu.tscn" and ResourceLoader.exists("res://assets/ui/app_icon.svg"), "包内主菜单入口与游戏图标可加载"):
		return
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art_catalog.json"))
	if not check(catalog is Dictionary and catalog.entries.size() == 26, "动态读取的图鉴JSON已打包"):
		return
	for entry: Dictionary in catalog.entries:
		if not check(ResourceLoader.exists(entry.path), "图鉴纹理存在：" + entry.id):
			return
	for id in ["shen_jin", "corpse", "ghost", "crossbow", "armored_xiao", "mountain_general"]:
		var path: String = "res://assets/animations/%s/manifest.json" % id
		if not check(FileAccess.file_exists(path) and JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary, "动作运行JSON存在：" + id):
			return
	if not check(FileAccess.file_exists("res://assets/enemies/shan_xiao/playable_v1/manifest.json"), "山魈动作JSON存在"):
		return
	for id in ["sword_entry", "broken_swords", "stepped_corridor", "archer_sanctum", "old_monument", "elite_den", "spirit_altar", "general_hall"]:
		var room: Node = load("res://scenes/rooms/%s.tscn" % id).instantiate()
		if not check(room != null, "包内房间及引用可实例化：" + id):
			return
		room.free()
	var app: Node = root.get_node("App")
	await app.return_to_menu()
	await frames()
	if not check(current_scene.has_node("%NewGame") and current_scene.has_node("%Continue"), "资源包实际进入主菜单"):
		return
	await app.start_new_game()
	await frames(12)
	if not check(current_scene.world.current_id == "entry" and current_scene.world.player.health == 100, "资源包实际进入首图，主角与地图资源就绪"):
		return
	app.set_paused(true)
	app.set_paused(false)
	if not check(not paused, "资源包暂停与恢复可执行"):
		return
	print("PACKAGED_RESOURCE_CHECKS_PASSED=", checks)
	quit()

func extra_jsons(path: String) -> Array:
	var extra: Array = []
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".json") and file not in ["manifest.json", "art_catalog.json"]:
			extra.append(path.path_join(file))
	for directory in DirAccess.get_directories_at(path):
		extra.append_array(extra_jsons(path.path_join(directory)))
	return extra
