extends RefCounted
## 八个手工模板组成十节点探索；仅随机支路用途和入口战斗房间的连接。
const ROOMS := {
	"entry": ["entry", "sword_entry", "剑冢入口"],
	"melee": ["combat", "broken_swords", "残剑荒地"],
	"platform": ["combat", "stepped_corridor", "断阶回廊"],
	"monument": ["event", "old_monument", "旧碑奇遇"],
	"archer": ["combat", "archer_sanctum", "弩傀儡祭室"],
	"elite": ["elite", "elite_den", "裂甲山魈巢穴"],
	"altar": ["altar", "spirit_altar", "灵脉祭坛"],
	"boss": ["boss", "general_hall", "镇山妖将大殿"]
}
var seed := 0
var nodes: Dictionary = {}

func generate(seed_value: int) -> void:
	seed = seed_value
	nodes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for id in ROOMS:
		_add_node(id, ROOMS[id])
	var reward := ["reward", "sword_entry", "遗落宝箱"]
	var shop := ["shop", "old_monument", "无面商人"]
	var reward_first := rng.randi_range(0, 1) == 0
	_add_node("side_before", reward if reward_first else shop)
	_add_node("side_after", shop if reward_first else reward)
	for edge in [
		["entry", "melee"], ["entry", "platform"],
		["melee", "monument"], ["platform", "monument"],
		["monument", "archer"], ["monument", "side_before"], ["side_before", "archer"],
		["archer", "elite"], ["archer", "side_after"], ["side_after", "elite"],
		["elite", "altar"], ["altar", "boss"]
	]:
		_connect(edge[0], edge[1])
	# 额外连接只在两间入口战斗房之间单向出现，保持无环和关键节点必经。
	match rng.randi_range(0, 2):
		1: _connect("melee", "platform")
		2: _connect("platform", "melee")

func _add_node(id: String, room: Array) -> void:
	nodes[id] = {
		"id": id, "kind": room[0], "template_id": room[1],
		"scene_path": "res://scenes/rooms/%s.tscn" % room[1], "label": room[2],
		"next": [], "previous": []
	}

func _connect(from: String, to: String) -> void:
	nodes[from].next.append(to)
	nodes[to].previous.append(from)
