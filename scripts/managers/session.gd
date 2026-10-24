extends Node
## 永久档案和探索快照统一提交；界面只能在文件确认成功后报告保存。
signal changed
signal feedback(message: String)
const Profile := preload("res://scripts/progression/profile_state.gd")
const Run := preload("res://scripts/roguelite/run_state.gd")
const SaveFile := preload("res://scripts/save/save_file.gd")
const Codec := preload("res://scripts/save/snapshot_codec.gd")
var profile: RefCounted
var store: RefCounted
var saved: Dictionary = {}
var pending_resume: Dictionary = {}
var message := ""
var blocked := false
var pending_death := false

func _ready() -> void:
	if store == null:
		# 可独立指定开发档位置，回归不会触碰玩家正式存档。
		var path := OS.get_environment("EMBERPEAK_SAVE_PATH")
		store = SaveFile.new(path if not path.is_empty() else "user://save_game.json", Codec.validate)
	load_profile()

func load_profile() -> void:
	profile = Profile.new()
	saved = {}
	pending_resume = {}
	var result: Dictionary = store.load_save()
	blocked = not result.accepted
	message = result.message
	if result.accepted and result.data != null:
		profile.restore(result.data.profile)
		saved = result.data.duplicate(true)
		if result.status == "recovered":
			# 旧备份不是最新探索事务；只恢复永久档案，不复活旧局领奖。
			saved.run_snapshot = null
			message += " 旧探索已停用，请用恢复的永久档案开始新探索。"
	changed.emit()

func clone_profile() -> RefCounted:
	var candidate := Profile.new()
	candidate.restore(profile.to_dict())
	return candidate

func can_continue() -> bool:
	return not blocked and not pending_death and saved.get("run_snapshot") is Dictionary

func begin_run() -> bool:
	if blocked or pending_death:
		notify("当前存档不可写或死亡结算待重试，已保留原件。" + message)
		return false
	pending_resume = {}
	# 新探索先使被放弃的旧局在磁盘失效，不能从菜单继续取回旧局物品。
	return commit_state(clone_profile(), null).accepted

func continue_run() -> bool:
	if not can_continue():
		notify("没有可继续的有效探索。" + message)
		return false
	pending_resume = saved.run_snapshot.duplicate(true)
	return true

func take_resume() -> Dictionary:
	var result := pending_resume
	pending_resume = {}
	return result

func commit_state(candidate: RefCounted, snapshot: Variant) -> Dictionary:
	if blocked:
		return notify("存档损坏或版本不兼容，禁止覆盖原件。")
	var envelope := {"save_version": 1, "revision": int(saved.get("revision", 0)) + 1, "profile": candidate.to_dict(), "run_snapshot": snapshot}
	var result: Dictionary = store.commit(envelope)
	message = result.message
	if result.accepted:
		profile = Profile.new()
		profile.restore(envelope.profile)
		saved = envelope.duplicate(true)
		changed.emit()
	feedback.emit(message)
	return result

func grow(route: Node) -> Dictionary:
	if route.run.ended or route.player.health <= 0 or pending_death:
		return {"accepted": false, "message": "探索已结束"}
	var candidate := clone_profile()
	var result: Dictionary = candidate.advance_minor(route.run.spirit)
	var boss_first: bool = route.run.to_dict().claimed.has("enemy:boss:0") and not candidate.boss_kills.has("mountain_general")
	if boss_first:
		candidate.boss_kills.append("mountain_general")
	if not result.accepted and not boss_first:
		return result
	var run_data: Dictionary = route.run.to_dict()
	run_data.spirit = result.pending
	var snapshot: Dictionary = route.capture_snapshot(run_data)
	_adjust_health(snapshot, candidate, route)
	var saved_result := commit_state(candidate, snapshot)
	if saved_result.accepted:
		route.run.restore(run_data)
		if not result.breakthroughs.is_empty():
			saved_result.message = "已自动突破并永久保存：" + "、".join(result.breakthroughs)
	return saved_result

func altar_action(route: Node, action: String, item_id: String = "") -> Dictionary:
	if pending_death or route.run.ended or route.player.health <= 0 or route.current_id != "altar" or not route.room.is_cleared or route.player.position.distance_to(route.room.altar_point) >= 120:
		return notify("请靠近灵脉祭坛进行操作。")
	var candidate := clone_profile()
	var run_data: Dictionary = route.run.to_dict()
	match action:
		"record":
			if not candidate.record_resources(route.run.spirit, route.run.stones, route.run.materials):
				return notify("资源数据无效，未记录。")
			run_data.spirit = 0
			run_data.stones = 0
			run_data.materials = {}
		"breakthrough":
			var result: Dictionary = candidate.major_breakthrough(route.run.spirit, route.run.materials, true)
			if not result.accepted:
				return notify(result.message)
			run_data.spirit = result.pending
			run_data.materials = result.materials
			for id in result.materials:
				if result.materials[id] == 0:
					run_data.materials.erase(id)
		"blueprint":
			var owned := false
			for item in route.inventory.items:
				if item.item_id == item_id:
					owned = true
			if not owned or candidate.blueprints.has(item_id):
				return notify("未持有该实物或蓝图已经登记。")
			candidate.blueprints.append(item_id)
			if item_id in ["qing_feng", "po_shan"] and not candidate.weapon_unlocks.has(item_id):
				candidate.weapon_unlocks.append(item_id)
		"save":
			pass
		_:
			return notify("未知祭坛操作。")
	var snapshot: Dictionary = route.capture_snapshot(run_data)
	_adjust_health(snapshot, candidate, route)
	var result := commit_state(candidate, snapshot)
	if result.accepted:
		route.run.restore(run_data)
		result.message = {"record": "灵气、灵石与材料已记录并保存。", "breakthrough": "已突破至%s，境界与消耗已永久保存。" % profile.stats().name, "blueprint": "蓝图已登记；武器解锁在死亡后保留。", "save": "探索快照已保存；未记录资源死亡仍会丢失。"}[action]
		message = result.message
	return result

func _adjust_health(snapshot: Dictionary, candidate: RefCounted, route: Node) -> void:
	var maximum: int = candidate.stats().max_health + route.inventory.modifiers().health_bonus + route.run.stat_modifiers().health_bonus
	snapshot.health = mini(maximum, route.player.health + maxi(0, maximum - route.player.stats.max_health))

func purchase(route: Node, good_id: String) -> Dictionary:
	var candidate := clone_profile()
	var current: RefCounted = Run.new()
	current.restore(route.run.to_dict())
	var pending: int = current.stones
	current.stones += candidate.banked_stones
	var result: Dictionary = current.buy(route.current_id, good_id, route.player.health, route.player.stats.max_health)
	if not result.accepted:
		return notify(result.message)
	var cost: int = current.rules.goods[good_id].price
	candidate.banked_stones -= maxi(0, cost - pending)
	current.stones = maxi(0, pending - cost)
	var snapshot: Dictionary = route.capture_snapshot(current.to_dict())
	snapshot.health = mini(route.player.stats.max_health, route.player.health + int(result.health_restored))
	var committed := commit_state(candidate, snapshot)
	if not committed.accepted:
		return committed
	route.run.restore(current.to_dict())
	return result

func save_death() -> Dictionary:
	var result := commit_state(clone_profile(), null)
	pending_death = not result.accepted
	if pending_death:
		message = "死亡结算保存失败，旧档未失效；请重试后再离开。 " + result.message
	return {"accepted": result.accepted, "message": message}

func notify(text: String) -> Dictionary:
	message = text
	feedback.emit(text)
	return {"accepted": false, "message": text}
