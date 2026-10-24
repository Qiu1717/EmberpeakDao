extends Control
const Ui := preload("res://scripts/ui/ui_style.gd")
var route: Node
var kind := ""
var payload: Dictionary = {}
var modal: Control
var body: VBoxContainer
var resources_label: Label
var attributes_label: Label
var app: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	theme = Ui.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 40
	bar.offset_right = -40
	bar.offset_top = -128
	bar.offset_bottom = -24
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(labels)
	resources_label = Ui.label(labels, "", 17)
	attributes_label = Ui.label(labels, "", 16)
	Ui.label(labels, "本局资源尚未登记 · 掉落与商品数值待平衡", 14)
	Ui.button(row, "本局行囊", "Inventory", func(): open("inventory", {}), self)
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.04, 0.06, 0.94)
	modal.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	modal.hide()

func bind(world: Node) -> void:
	route = world
	route.interaction_requested.connect(open)
	route.run.changed.connect(_refresh_hud)
	_refresh_hud()

func _refresh_hud() -> void:
	resources_label.text = "丹田灵气 %d　灵石 %d　材料 %d 类　装备掉落 %d 件" % [route.run.spirit, route.run.stones, route.run.materials.size(), route.run.equipment_rewards.size()]
	var values: Dictionary = route.run.stat_modifiers()
	attributes_label.text = "本局加成　攻击 +%d%%　生命 +%d　防御 +%d　暴击 +%d%%　闪避冷却 −%d%%　攻速 +%d%%" % [roundi((values.attack_multiplier - 1.0) * 100), values.health_bonus, values.defense_bonus, roundi(values.crit_bonus * 100), roundi(values.dodge_reduction * 100), roundi(values.haste * 100)]

func open(next_kind: String, data: Dictionary) -> void:
	if app.state == app.State.PAUSED or (route.run.ended and next_kind != "death"):
		return
	kind = next_kind
	payload = data
	app.set_modal_active(true)
	modal.show()
	_build()

func _clear_body() -> void:
	for node in body.get_children():
		for button in node.find_children("*", "Button", true, false):
			button.unique_name_in_owner = false
		node.unique_name_in_owner = false
		body.remove_child(node)
		node.queue_free()

func _build() -> void:
	_clear_body()
	match kind:
		"route":
			Ui.label(body, "剑冢岔路", 32)
			Ui.label(body, "选择下一处房间；已清理的房间不会重复发奖。", 16)
			for node in payload.choices:
				var description: String = {"entry": "入口", "combat": "战斗", "event": "奇遇", "shop": "商店", "reward": "奖励", "elite": "精英", "altar": "休整", "boss": "Boss"}[node.kind]
				Ui.button(body, "%s · %s%s" % [node.label, description, " · 已清理" if route.cleared_rooms.has(node.id) else ""], "Route_" + node.id, _travel.bind(node.id), self)
			if payload.choices.is_empty():
				Ui.label(body, "此方向没有可走的路线，请从另一侧出口返回。")
		"upgrade":
			Ui.label(body, "清场所得 · 三选一", 32)
			Ui.label(body, "仅在本局生效；关闭后可按交互键继续选择。", 16)
			for id in payload.options:
				var item: Dictionary = route.run.rules.upgrades[id]
				Ui.button(body, "%s　%d / %d 层\n%s" % [item.name, route.run.upgrades.get(id, 0), item.cap, item.description], "Upgrade_" + id, _choose.bind(id), self)
		"event":
			var event: Dictionary = route.run.rules.events[payload.event_id]
			Ui.label(body, event.name, 32)
			_paragraph(event.description)
			for id in event.choices:
				var option: Dictionary = event.choices[id]
				Ui.button(body, option.name + "\n" + option.description, "Event_" + id, _event.bind(id), self)
		"shop":
			Ui.label(body, "无面商人 · 灵石 %d" % route.run.stones, 32)
			var portrait := TextureRect.new()
			portrait.texture = preload("res://assets/npcs/concepts/faceless.png")
			portrait.custom_minimum_size = Vector2(0, 100)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			body.add_child(portrait)
			Ui.label(body, "商人概念图 · 当前库存限本次探索", 14)
			for good in route.run.shop_inventory(route.current_id):
				var button := Ui.button(body, "%s　%d 灵石　余 %d\n%s" % [good.name, good.price, good.remaining, good.description], "Buy_" + good.id, _buy.bind(good.id), self)
				button.disabled = good.remaining <= 0 or route.run.stones < good.price
		"inventory":
			Ui.label(body, "本局行囊", 32)
			_paragraph("种子：%d\n未记录丹田灵气 %d；灵石 %d。死亡或重新开始后清除。" % [route.run.seed, route.run.spirit, route.run.stones])
			for id in route.run.materials:
				Ui.label(body, "%s × %d" % [route.run.rules.material_names.get(id, id), route.run.materials[id]])
			Ui.label(body, "装备掉落（穿戴功能将在后续阶段开放）", 20)
			for item in route.run.equipment_rewards:
				Ui.label(body, item.name)
			if route.run.equipment_rewards.is_empty():
				Ui.label(body, "尚未获得装备")
		"death":
			Ui.label(body, "此行已尽", 36)
			_paragraph("本局强化和未记录的资源已清除。\n重新探索将生成新的路线与奖励。")
			_paragraph("本次丢失：丹田灵气 %d、灵石 %d、材料 %d 类、装备 %d 件。" % [payload.spirit, payload.stones, payload.materials.size(), payload.equipment_rewards.size()])
			Ui.button(body, "重新探索", "NewRun", app.start_new_game, self)
			Ui.button(body, "返回主菜单", "ReturnMenu", app.return_to_menu, self)
	var feedback := Ui.label(body, route.last_reward, 16)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Ui.button(body, "关闭", "CloseRunPanel", close, self)
	for child in body.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			break

func _paragraph(text: String) -> void:
	var label := Ui.label(body, text, 18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _travel(id: String) -> void:
	close()
	route.travel_to(id)

func _choose(id: String) -> void:
	if route.choose_upgrade(id):
		close()

func _event(id: String) -> void:
	if route.resolve_event(id).accepted:
		close()
	else:
		_build()

func _buy(id: String) -> void:
	route.buy(id)
	_build()

func close() -> void:
	modal.hide()
	kind = ""
	# UI 内的点击/移动不能在恢复时变成世界中的缓冲攻击或跳跃。
	for action in ["attack", "dodge", "jump", "move_left", "move_right", "interact"]:
		Input.action_release(action)
	route.player.attack_requested = false
	route.player.dodge_requested = false
	route.player.jump_remaining = 0
	app.set_modal_active(false)

func _input(event: InputEvent) -> void:
	if modal.visible and event.is_action_pressed("pause") and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()
