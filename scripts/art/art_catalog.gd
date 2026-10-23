extends RefCounted
## 只提供现有美术资料，不代表NPC、装备或事件系统已实现。
static func entries() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/art_catalog.json")).entries

static func entry(id: String) -> Dictionary:
	for item: Dictionary in entries():
		if item.id == id:
			return item
	return {}

static func texture(id: String) -> Texture2D:
	return load(entry(id).path)
