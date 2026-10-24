extends RefCounted
## 只负责完整封套文件；玩法语义由调用方校验，不生成默认档案。

const SAVE_VERSION := 1
const MAX_JSON_INTEGER := 9007199254740991
var _path: String
var _validator: Callable

func _init(path: String, validator: Callable = Callable()) -> void:
	_path = ProjectSettings.globalize_path(path)
	_validator = validator

func load_save() -> Dictionary:
	var primary := _read(_path)
	if primary.status == "loaded" or primary.status == "incompatible":
		return _result(primary.accepted, primary.status, primary.message, primary.data)
	var backup := _read(_path + ".bak")
	if backup.status == "loaded":
		return _result(true, "recovered", "主档不可读取，已读取有效备份（提交 %s）；原件已保留。" % backup.data.revision, backup.data)
	if backup.status == "incompatible":
		return _result(false, "incompatible", "备份版本不受支持，已保留原件，未降级或覆盖。")
	if primary.status == "missing" and backup.status == "missing":
		return _result(true, "missing", "尚无游戏存档。")
	return _result(false, "corrupt", "主档与备份均不可用，已保留原件。")

func commit(data: Dictionary) -> Dictionary:
	var candidate := _inspect(data)
	if not candidate.accepted:
		return {"accepted": false, "message": "保存失败：" + candidate.message}
	var primary := _read(_path)
	var backup := _read(_path + ".bak")
	if primary.status == "incompatible" or backup.status == "incompatible":
		return {"accepted": false, "message": "保存失败：存在不受支持的存档版本，禁止覆盖原件。"}
	if primary.status != "loaded" and backup.status != "loaded" \
			and (primary.status != "missing" or backup.status != "missing"):
		return {"accepted": false, "message": "保存失败：现有存档损坏，须保留原件。"}
	var contents := JSON.stringify(candidate.data, "", true, true)
	var written := _write_checked(_path + ".tmp", contents)
	if not written.accepted:
		return written
	if primary.status == "loaded":
		# Windows覆盖rename有移除目标的间隙；备份更新时主档仍完整存在。
		written = _write_checked(_path + ".bak.tmp", primary.contents)
		if not written.accepted:
			return written
		if DirAccess.dir_exists_absolute(_path + ".bak") \
				or DirAccess.rename_absolute(_path + ".bak.tmp", _path + ".bak") != OK:
			return {"accepted": false, "message": "保存失败：无法更新有效备份，原主档已保留。"}
	# 恢复自备份时不轮换备份，避免损坏主档覆盖最后一份有效数据。
	if DirAccess.dir_exists_absolute(_path) or DirAccess.rename_absolute(_path + ".tmp", _path) != OK:
		return {"accepted": false, "message": "保存失败：无法替换主档，上一有效提交仍由主档或备份保留。"}
	return {"accepted": true, "message": "游戏已保存。"}

func _write_checked(path: String, contents: String) -> Dictionary:
	var parent := path.get_base_dir()
	if FileAccess.file_exists(parent) or DirAccess.dir_exists_absolute(path):
		return {"accepted": false, "message": "保存失败：目标路径被文件或目录占用。"}
	if DirAccess.make_dir_recursive_absolute(parent) != OK:
		return {"accepted": false, "message": "保存失败：无法创建存档目录。"}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"accepted": false, "message": "保存失败：无法写入临时文件。"}
	file.store_string(contents)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return {"accepted": false, "message": "保存失败：临时文件写入不完整。"}
	var verified := _read(path)
	if verified.status != "loaded" or verified.get("contents") != contents:
		return {"accepted": false, "message": "保存失败：临时文件重新读取校验未通过。"}
	return {"accepted": true, "message": "临时文件校验通过。"}

func _read(path: String) -> Dictionary:
	if DirAccess.dir_exists_absolute(path):
		return _result(false, "corrupt", "存档路径被目录占用。")
	if not FileAccess.file_exists(path):
		return _result(true, "missing", "存档文件不存在。")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _result(false, "corrupt", "存档文件无法读取。")
	var contents := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(contents) != OK:
		return _result(false, "corrupt", "存档内容不是完整JSON。")
	var inspected := _inspect(json.data)
	if inspected.accepted:
		inspected["contents"] = contents
	return inspected

func _inspect(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _result(false, "corrupt", "存档封套必须为字典。")
	var version: Variant = value.get("save_version")
	if not _positive_integer(version):
		return _result(false, "corrupt", "存档缺少合法版本号。")
	if version != SAVE_VERSION:
		return _result(false, "incompatible", "存档版本不受支持，需要明确迁移，原件已保留。")
	if not _positive_integer(value.get("revision")) or value.revision > MAX_JSON_INTEGER:
		return _result(false, "corrupt", "存档提交编号无效或超出JSON安全整数范围。")
	if not value.get("profile") is Dictionary or not value.has("run_snapshot") \
			or (value.run_snapshot != null and not value.run_snapshot is Dictionary):
		return _result(false, "corrupt", "存档缺少完整档案或探索快照，或字段类型不符。")
	var data: Dictionary = value.duplicate(true)
	data.save_version = int(version)
	data.revision = int(data.revision)
	if _validator.is_valid() and not _validator.call(data):
		return _result(false, "corrupt", "档案或探索快照未通过完整语义校验。")
	return _result(true, "loaded", "已读取完整存档。", data)

func _positive_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and value > 0 and floor(float(value)) == float(value)

func _result(accepted: bool, status: String, message: String, data: Variant = null) -> Dictionary:
	return {"accepted": accepted, "status": status, "message": message, "data": data}
