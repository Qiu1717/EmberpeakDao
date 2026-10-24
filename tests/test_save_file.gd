extends SceneTree

var checks := 0
var failures := 0
var save_script: Script
var test_root := "user://phase5_test_%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/save/save_file.gd"), "独立存档模块存在，首次读取可执行")
	if failures > 0:
		quit(1)
		return
	save_script = load("res://scripts/save/save_file.gd")
	_test_missing_and_round_trip()
	_test_bad_primary_and_recovery()
	_test_unreadable_and_versions()
	_test_semantic_validation()
	_test_invalid_candidates()
	_test_real_write_failures()
	_test_windows_locked_files()
	_test_interrupted_temporary_files()
	_remove_test_tree(test_root)
	if failures == 0:
		print("SAVE_FILE_CHECKS_PASSED=", checks)
	quit(1 if failures else 0)

func _fixture(revision: int = 1) -> Dictionary:
	return {
		"save_version": 1, "revision": revision,
		"profile": {"recorded_spirit": 17, "unlocked_weapons": ["qing_feng"]},
		"run_snapshot": {"run_id": "test-run", "rng_state": "9223372036854775806", "reward_claims": ["enemy:1"]},
	}

func _path(name: String) -> String:
	return test_root.path_join(name).path_join("slot.json")

func _write(path: String, contents: String) -> void:
	check(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK, "建立独立测试目录")
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "写入真实存档测试夹具")
	if file != null:
		file.store_string(contents)
		file.close()

func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _test_missing_and_round_trip() -> void:
	var path := _path("round_trip")
	var storage = save_script.new(path)
	var result: Dictionary = storage.load_save()
	check(result.accepted and result.status == "missing" and result.data == null, "首启无文件返回missing且不伪造档案")
	check(not DirAccess.dir_exists_absolute(path.get_base_dir()), "只读首启不创建目录或文件")
	check(storage.commit(_fixture()).accepted, "完整封套首次写入成功")
	check(FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".tmp"), "成功提交只留下正式文件，不残留待提交文件")
	result = save_script.new(path).load_save()
	check(result.accepted and result.status == "loaded" and result.data.revision == 1, "新实例读回已提交版本")
	check(result.data.profile.recorded_spirit == 17 and result.data.run_snapshot.reward_claims == ["enemy:1"], "永久档案与探索快照同档往返")
	check(result.data.run_snapshot.rng_state == "9223372036854775806", "字符串RNG状态不受JSON数字精度影响")
	var original := _text(path)
	var next := _fixture(2)
	next.profile.recorded_spirit = 31
	next.run_snapshot = null
	check(storage.commit(next).accepted, "死亡式空探索快照可整体保存")
	result = save_script.new(path).load_save()
	check(result.status == "loaded" and result.data.revision == 2 and result.data.run_snapshot == null, "新提交整体替换旧档，未混用旧探索")
	check(_text(path + ".bak") == original, "有效备份保留上一完整提交")
	check(not FileAccess.file_exists(path + ".bak.tmp"), "成功备份不残留临时文件")
	check(storage.commit(_fixture(3)).accepted, "已有备份时仍可完成下一次提交")
	var backup: Variant = JSON.parse_string(_text(path + ".bak"))
	check(backup.revision == 2 and backup.run_snapshot == null, "备份随成功提交更新为上一有效版本")

func _test_bad_primary_and_recovery() -> void:
	var variants: Array = [
		'{"save_version":1,',
		'{"save_version":1,"revision":2,"profile":{}}',
		'{"save_version":1,"revision":2,"profile":[],"run_snapshot":null}',
		'{"save_version":1,"revision":2,"profile":{},"run_snapshot":false}',
		'{"save_version":1,"revision":0,"profile":{},"run_snapshot":null}',
		'{"save_version":1,"revision":1.5,"profile":{},"run_snapshot":null}',
		'[]',
	]
	for index in variants.size():
		var path := _path("recover_%s" % index)
		_write(path, variants[index])
		_write(path + ".bak", JSON.stringify(_fixture()))
		var storage = save_script.new(path)
		var result: Dictionary = storage.load_save()
		check(result.accepted and result.status == "recovered" and result.data.revision == 1, "截断／字段／类型损坏主档从有效备份恢复：%s" % index)
		check(_text(path) == variants[index], "恢复只读且保留损坏原件：%s" % index)
		var good_backup := _text(path + ".bak")
		check(storage.commit(_fixture(2)).accepted, "备份恢复后可以提交新封套：%s" % index)
		check(_text(path + ".bak") == good_backup, "损坏主档不得覆盖最后有效备份：%s" % index)
		check(save_script.new(path).load_save().data.revision == 2, "恢复后新主档可再次读出：%s" % index)
	var absent := _path("missing_primary")
	_write(absent + ".bak", JSON.stringify(_fixture(4)))
	var recovered: Dictionary = save_script.new(absent).load_save()
	check(recovered.accepted and recovered.status == "recovered" and recovered.data.revision == 4, "中断遗失主档时仍能从已提交备份恢复")
	check(not FileAccess.file_exists(absent), "缺主档的恢复也不自动重写原件")

func _test_unreadable_and_versions() -> void:
	var path := _path("both_corrupt")
	_write(path, "broken-main")
	_write(path + ".bak", "broken-backup")
	var storage = save_script.new(path)
	var result: Dictionary = storage.load_save()
	check(not result.accepted and result.status == "corrupt" and result.data == null and not result.message.is_empty(), "主备都坏时明确拒绝且返回提示")
	check(not storage.commit(_fixture()).accepted and _text(path) == "broken-main" and _text(path + ".bak") == "broken-backup", "都坏时不自动覆盖原件")
	var future := _fixture(8)
	future.save_version = 99
	for name in ["future_primary", "future_backup"]:
		path = _path(name)
		_write(path if name == "future_primary" else path + ".bak", JSON.stringify(future))
		if name == "future_primary":
			_write(path + ".bak", JSON.stringify(_fixture()))
		else:
			_write(path, "broken")
		storage = save_script.new(path)
		result = storage.load_save()
		check(not result.accepted and result.status == "incompatible" and result.data == null, "未知新版本拒绝降级：" + name)
		var old_main := _text(path)
		var old_backup := _text(path + ".bak")
		check(not storage.commit(_fixture(9)).accepted and _text(path) == old_main and _text(path + ".bak") == old_backup, "未知新版本不允许覆盖原文件：" + name)

func _valid_spirit(data: Dictionary) -> bool:
	var value: Variant = data.profile.get("recorded_spirit")
	return (value is int or value is float) and value >= 0

func _test_semantic_validation() -> void:
	var path := _path("semantic")
	var invalid := _fixture(2)
	invalid.profile.recorded_spirit = -5
	_write(path, JSON.stringify(invalid))
	_write(path + ".bak", JSON.stringify(_fixture()))
	var storage = save_script.new(path, _valid_spirit)
	var result: Dictionary = storage.load_save()
	check(result.accepted and result.status == "recovered" and result.data.profile.recorded_spirit == 17, "调用方语义校验失败的主档必须回退有效备份")
	var good_backup := _text(path + ".bak")
	check(storage.commit(_fixture(3)).accepted and _text(path + ".bak") == good_backup, "语义不合法主档也不得覆盖有效备份")
	var original := _text(path)
	check(not storage.commit(invalid).accepted and _text(path) == original and _text(path + ".bak") == good_backup, "调用方拒绝候选时磁盘原档完全不变")
	_write(path + ".bak", JSON.stringify(invalid))
	_write(path, JSON.stringify(invalid))
	result = storage.load_save()
	check(not result.accepted and result.status == "corrupt", "主备语义都不合法时安全拒绝")

func _test_invalid_candidates() -> void:
	var path := _path("invalid_candidates")
	var storage = save_script.new(path)
	check(storage.commit(_fixture()).accepted, "为无效候选用例建立有效原档")
	var original := _text(path)
	var variants: Array = [
		{},
		{"save_version": 1, "revision": 2, "profile": {}},
		{"save_version": 1, "revision": true, "profile": {}, "run_snapshot": null},
		{"save_version": 1, "revision": -1, "profile": {}, "run_snapshot": null},
		{"save_version": "1", "revision": 2, "profile": {}, "run_snapshot": null},
		{"save_version": 1, "revision": 2, "profile": [], "run_snapshot": null},
		{"save_version": 1, "revision": 2, "profile": {}, "run_snapshot": []},
		{"save_version": 7, "revision": 2, "profile": {}, "run_snapshot": null},
	]
	for index in variants.size():
		var result: Dictionary = storage.commit(variants[index])
		check(not result.accepted and not result.message.is_empty() and _text(path) == original, "无效封套不替换有效存档：%s" % index)
	check(not FileAccess.file_exists(path + ".bak"), "无效候选也不轮换有效备份")

func _test_real_write_failures() -> void:
	var blocked_parent := test_root.path_join("parent_is_file")
	_write(blocked_parent, "keep-parent")
	var result: Dictionary = save_script.new(blocked_parent.path_join("slot.json")).commit(_fixture())
	check(not result.accepted and not result.message.is_empty() and _text(blocked_parent) == "keep-parent", "父路径是文件时真实写失败且保留原件")
	var path := _path("primary_is_directory")
	check(DirAccess.make_dir_recursive_absolute(path) == OK, "建立被目录占用的主档路径")
	result = save_script.new(path).commit(_fixture())
	check(not result.accepted and DirAccess.dir_exists_absolute(path), "主档被目录占用时拒绝替换目录")
	for suffix in [".tmp", ".bak", ".bak.tmp"]:
		path = _path("occupied_%s" % suffix)
		var storage = save_script.new(path)
		check(storage.commit(_fixture()).accepted, "为真实写失败用例建立有效主档：" + suffix)
		var original := _text(path)
		check(DirAccess.make_dir_recursive_absolute(path + suffix) == OK, "目录占用保存中间路径：" + suffix)
		result = storage.commit(_fixture(2))
		check(not result.accepted and not result.message.is_empty(), "实际临时写／备份失败返回明确拒绝：" + suffix)
		check(_text(path) == original and save_script.new(path).load_save().data.revision == 1, "保存失败后原有效档仍完整可读：" + suffix)

func _test_windows_locked_files() -> void:
	if OS.get_name() != "Windows":
		return
	for suffix in ["", ".bak"]:
		var path := _path("locked_%s" % suffix)
		var storage = save_script.new(path)
		check(storage.commit(_fixture()).accepted and storage.commit(_fixture(2)).accepted, "为Windows文件占用用例建立主备档")
		var original := _text(path)
		var held := FileAccess.open(path + suffix, FileAccess.READ)
		check(held != null, "持有真实Windows文件句柄：" + suffix)
		var result: Dictionary = storage.commit(_fixture(3))
		check(not result.accepted and _text(path) == original, "Windows实际替换失败不丢失原主档：" + suffix)
		held.close()
		check(save_script.new(path).load_save().data.revision == 2, "文件占用失败后可重新读取上一提交：" + suffix)

func _test_interrupted_temporary_files() -> void:
	var path := _path("only_tmp")
	_write(path + ".tmp", JSON.stringify(_fixture(99)))
	_write(path + ".bak.tmp", JSON.stringify(_fixture(98)))
	var result: Dictionary = save_script.new(path).load_save()
	check(result.accepted and result.status == "missing" and result.data == null, "孤立tmp和bak.tmp不能冒充已提交存档")
	check(save_script.new(path).commit(_fixture()).accepted, "新提交可覆盖孤立临时文件")
	result = save_script.new(path).load_save()
	check(result.status == "loaded" and result.data.revision == 1, "只读回实际成功提交，忽略临时文件中的高revision")
	_write(path + ".tmp", "truncated temporary")
	result = save_script.new(path).load_save()
	check(result.status == "loaded" and result.data.revision == 1, "中断临时写不影响上一次已提交档案")

func _remove_test_tree(path: String) -> void:
	var resolved := ProjectSettings.globalize_path(path).replace("\\", "/")
	var expected := ProjectSettings.globalize_path(test_root).replace("\\", "/")
	if resolved != expected and not resolved.begins_with(expected + "/"):
		check(false, "清理路径必须限制在本轮独立测试目录")
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	for name in dir.get_directories():
		_remove_test_tree(path.path_join(name))
	DirAccess.remove_absolute(path)
