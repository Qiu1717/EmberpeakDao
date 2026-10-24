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
func _run() -> void:
	if not check(ResourceLoader.exists("res://scripts/managers/session.gd"), "永久档案与探索事务服务存在"):
		return
	var folder := "user://phase5_session_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder + "/save.json"
	var store_script: Script = load("res://scripts/save/save_file.gd")
	var codec: Script = load("res://scripts/save/snapshot_codec.gd")
	var session: Node = load("res://scripts/managers/session.gd").new()
	session.store = store_script.new(path, codec.validate)
	root.add_child(session)
	if not check(session.profile.realm == 0 and session.profile.subrealm == 0 and not session.can_continue() and not FileAccess.file_exists(path), "首次无档初始化且不伪造已保存进度"):
		return
	var run: RefCounted = load("res://scripts/roguelite/run_state.gd").new(318)
	var inventory: RefCounted = load("res://scripts/inventory/inventory_state.gd").new()
	inventory.add_item({"instance_id": "base:qing_feng", "item_id": "qing_feng", "name": "青锋旧剑"})
	inventory.equip("base:qing_feng", 0)
	var snapshot := {"run": run.to_dict(), "inventory": inventory.to_dict(), "current_id": "entry", "visited": {"entry": true}, "cleared_rooms": {"entry": true}, "upgrade_pending": {}, "health": 100, "qi": 60.0, "enemies": {}}
	var candidate: RefCounted = session.clone_profile()
	candidate.banked_spirit = 30
	if not check(session.commit_state(candidate, snapshot).accepted and session.can_continue(), "真实保存永久档案与一致探索封套"):
		return
	var growth: Dictionary = candidate.advance_minor(25)
	run.spirit = growth.pending
	snapshot.run = run.to_dict()
	if not check(session.commit_state(candidate, snapshot).accepted and session.profile.subrealm == 1 and session.profile.banked_spirit == 15, "消耗新增25和已记录15，永久小境界事务正确"):
		return
	if not check(session.begin_run() and not session.can_continue() and session.store.load_save().data.run_snapshot == null, "新探索先持久化失效旧快照，不能继续被放弃的旧局"):
		return
	session.commit_state(session.clone_profile(), snapshot)
	var before := FileAccess.get_file_as_string(path)
	var working_store = session.store
	DirAccess.make_dir_absolute(folder + "/blocked")
	session.store = store_script.new(folder + "/blocked", codec.validate)
	var failed_candidate: RefCounted = session.clone_profile()
	failed_candidate.advance_minor(60)
	if not check(not session.commit_state(failed_candidate, snapshot).accepted and session.profile.subrealm == 1 and session.profile.banked_spirit == 15 and FileAccess.get_file_as_string(path) == before, "写失败不发布境界、不损坏已保存状态并有反馈"):
		return
	session.store = working_store
	if not check(session.commit_state(session.clone_profile(), null).accepted and not session.can_continue(), "死亡结算使旧探索快照失效"):
		return
	var loaded: Node = load("res://scripts/managers/session.gd").new()
	loaded.store = store_script.new(path, codec.validate)
	root.add_child(loaded)
	if not check(loaded.profile.subrealm == 1 and loaded.profile.banked_spirit == 15 and not loaded.can_continue(), "重新载入保留已保存境界与真实剩余余额，不复活旧局"):
		return
	loaded.queue_free()
	session.queue_free()
	print("SESSION_CHECKS_PASSED=", checks)
	quit()
