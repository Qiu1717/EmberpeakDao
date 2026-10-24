extends Control
const Ui := preload("res://scripts/ui/ui_style.gd")
const NpcDialogue := preload("res://scripts/ui/npc_dialogue.gd")
var route: Node
var kind := ""
var payload: Dictionary = {}
var modal: Control
var body: VBoxContainer
var resources_label: Label
var attributes_label: Label
var qi_label: Label
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
	qi_label = Ui.label(labels, "", 14)
	Ui.label(labels, "境界与已记录余额永久保留 · 未记录资源死亡丢失 · 数值待平衡", 14)
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
	route.session.changed.connect(_refresh_hud)
	_refresh_hud()

func _refresh_hud() -> void:
	var profile: RefCounted = route.session.profile
	var stage: Dictionary = profile.stats()
	resources_label.text = "%s　丹田灵气 %d / %s（已记录%d＋新增%d）　灵石 %d＋%d" % [stage.name, profile.banked_spirit + route.run.spirit, str(stage.required_spirit) if stage.required_spirit > 0 else "首图上限", profile.banked_spirit, route.run.spirit, profile.banked_stones, route.run.stones]
	var values: Dictionary = route.run.stat_modifiers()
	attributes_label.text = "本局加成　攻击 +%d%%　生命 +%d　防御 +%d　暴击 +%d%%　闪避冷却 −%d%%　攻速 +%d%%" % [roundi((values.attack_multiplier - 1.0) * 100), values.health_bonus, values.defense_bonus, roundi(values.crit_bonus * 100), roundi(values.dodge_reduction * 100), roundi(values.haste * 100)]

func _process(_delta: float) -> void:
	if route != null and not modal.visible:
		qi_label.text = "真气 %.1f / %.0f　恢复 %.1f/秒　%s　强化 %d 项　药品 %d / 2" % [route.player.qi, route.player.stats.qi_max, route.player.stats.qi_regen, route.inventory.catalog.items[route.inventory.weapon_id()].name if not route.inventory.weapon_id().is_empty() else "未装备武器", route.run.upgrades.size(), route.medicine]

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
		"npc":
			NpcDialogue.build(self, payload.npc_id)
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
			Ui.label(body, "无面商人 · 可用灵石 %d" % (route.run.stones + route.session.profile.banked_stones), 32)
			var portrait := TextureRect.new()
			portrait.texture = preload("res://assets/npcs/concepts/faceless.png")
			portrait.custom_minimum_size = Vector2(0, 100)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			body.add_child(portrait)
			Ui.label(body, "商人概念图 · 当前库存限本次探索", 14)
			for good in route.run.shop_inventory(route.current_id):
				var button := Ui.button(body, "%s　%d 灵石　余 %d\n%s" % [good.name, good.price, good.remaining, good.description], "Buy_" + good.id, _buy.bind(good.id), self)
				button.disabled = good.remaining <= 0 or route.run.stones + route.session.profile.banked_stones < good.price
		"inventory":
			Ui.label(body, "本局行囊", 32)
			_paragraph("种子：%d\n%s；未记录丹田灵气 %d，灵石 %d。掉落实物死亡清除。" % [route.run.seed, route.session.profile.stats().name, route.run.spirit, route.run.stones])
			for slot in ["weapon", "armor", "accessory"]:
				var equipped_id: String = route.inventory.equipped.get(slot, "")
				var held: Array = route.inventory.items.filter(func(item): return item.instance_id == equipped_id)
				Ui.label(body, {"weapon": "武器", "armor": "防具", "accessory": "饰品"}[slot] + "：" + (held[0].name if not held.is_empty() else "空"))
			Ui.label(body, "新增材料（死亡丢失）", 18)
			for id in route.run.materials:
				Ui.label(body, "%s × %d" % [route.run.rules.material_names.get(id, id), route.run.materials[id]])
			Ui.label(body, "已记录材料（保留未消耗余额）", 18)
			for id in route.session.profile.banked_materials:
				if route.session.profile.banked_materials[id] > 0:
					Ui.label(body, "%s × %d" % [route.run.rules.material_names.get(id, id), route.session.profile.banked_materials[id]])
			Ui.label(body, "装备实物 · 点击查看属性与装卸", 20)
			for item in route.inventory.items:
				Ui.button(body, item.name, "Item_" + str(route.inventory.items.find(item)), open.bind("equipment", {"instance_id": item.instance_id}), self)
			var blueprints: Array[String] = []
			for id in route.session.profile.blueprints:
				blueprints.append(route.inventory.catalog.items[id].name)
			_paragraph("已登记蓝图：" + ("、".join(blueprints) if not blueprints.is_empty() else "无"))
			if route.session.message.contains("保存失败"):
				Ui.button(body, "重试自动突破保存", "RetryGrowthSave", _retry_growth, self)
		"equipment":
			var records: Array = route.inventory.items.filter(func(item): return item.instance_id == payload.instance_id)
			if records.is_empty():
				close()
				return
			var record: Dictionary = records[0]
			var item: Dictionary = route.inventory.catalog.items[record.item_id]
			Ui.label(body, item.name, 32)
			if not item.icon_path.is_empty():
				var reference := TextureRect.new()
				reference.texture = load(item.icon_path)
				reference.custom_minimum_size = Vector2(0, 110)
				reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				body.add_child(reference)
				Ui.label(body, "现有装备设定参考 · 独立图标与持物外观待制作", 14)
			_paragraph("品阶：%s　稀有度：普通\n要求：%s境；当前：%s" % [["凡品", "灵器", "法器", "宝器", "灵宝"][item.tier], ["炼气", "筑基", "金丹", "元婴", "化神"][item.required_realm], route.session.profile.stats().name])
			if item.has("damage"):
				_paragraph("基础攻击：" + str(item.damage))
			var effect_names := {"max_health": "最大生命", "defense": "防御", "max_qi": "真气上限", "third_attack_multiplier": "第三段攻击加成", "qi_regen_multiplier": "真气恢复加成"}
			for effect in item.effects:
				Ui.label(body, "%s：+%s" % [effect_names.get(effect, effect), str(item.effects[effect] * 100) + "%" if effect.ends_with("multiplier") else str(item.effects[effect])])
			if record.item_id == "po_shan":
				_paragraph("长枪与重击的判定已实现；动作暂借剑术候选帧，正式姿势待制作。")
			var worn: bool = route.inventory.equipped.get(item.slot) == record.instance_id
			Ui.button(body, "卸下" if worn else "装备", "EquipItem", _equip.bind(record.instance_id, item.slot, worn), self)
			if route.current_id == "altar":
				var register := Ui.button(body, "在祭坛登记蓝图", "RegisterBlueprint", _altar.bind("blueprint", record.item_id), self)
				register.disabled = route.session.profile.blueprints.has(record.item_id)
			Ui.button(body, "返回行囊", "BackInventory", open.bind("inventory", {}), self)
		"altar":
			Ui.label(body, "残灯婆婆 · 灵脉祭坛 · " + route.session.profile.stats().name, 28)
			NpcDialogue.portrait(body, route.services.characters.can_deng)
			_paragraph("记录将新增灵气、灵石和材料转入永久余额；单独保存快照不会记录资源。小境界满灵气自动突破，大境界须圆满并具对应材料。")
			_paragraph("已记录：灵气%d、灵石%d\n未记录：灵气%d、灵石%d\n筑基灵髓：已记录%d＋新增%d" % [route.session.profile.banked_spirit, route.session.profile.banked_stones, route.run.spirit, route.run.stones, route.session.profile.banked_materials.get("foundation_marrow", 0), route.run.materials.get("foundation_marrow", 0)])
			Ui.button(body, "记录资源并保存", "AltarRecord", _altar.bind("record", ""), self)
			Ui.button(body, "突破大境界", "AltarBreakthrough", _altar.bind("breakthrough", ""), self)
			Ui.button(body, "只保存探索快照", "AltarSave", _altar.bind("save", ""), self)
			Ui.button(body, "整理装备与登记蓝图", "AltarInventory", open.bind("inventory", {}), self)
			if route.cleared_rooms.has("boss"):
				_paragraph("妖将已败。返回驻地会在此记录资源并结束本次探索；局内强化和掉落实物将清除。请先完成所需突破和蓝图登记。")
				Ui.button(body, "记录资源、结束探索并返回驻地", "CompleteExploration", _complete, self)
		"death":
			Ui.label(body, "此行已尽", 36)
			_paragraph("本局强化和未记录的资源已清除。\n重新探索将生成新的路线与奖励。")
			_paragraph("本次丢失：丹田灵气 %d、灵石 %d、材料 %d 类、装备 %d 件。" % [payload.spirit, payload.stones, payload.materials.size(), payload.equipment_rewards.size()])
			_paragraph("保留：%s、已记录灵气%d／灵石%d、登记蓝图%d份。" % [route.session.profile.stats().name, route.session.profile.banked_spirit, route.session.profile.banked_stones, route.session.profile.blueprints.size()])
			if route.session.pending_death:
				Ui.button(body, "重试死亡结算保存", "RetryDeath", _retry_death, self)
			else:
				Ui.button(body, "重新探索", "NewRun", app.start_new_game, self)
				Ui.button(body, "返回问道残庭", "ReturnHome", app.return_to_home, self)
				Ui.button(body, "返回主菜单", "ReturnMenu", app.return_to_menu, self)
	var feedback := Ui.label(body, route.last_reward, 16)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if kind != "death" or not route.session.pending_death:
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

func _npc(action: String, item_id: String = "") -> void:
	var result: Dictionary = route.npc_action(payload.npc_id, action, item_id)
	if result.accepted and action == "practice":
		close()
	else:
		_build()

func _equip(id: String, slot: String, worn: bool) -> void:
	if worn:
		route.unequip(slot)
	else:
		route.equip_item(id)
	_refresh_hud()
	_build()

func _altar(action: String, id: String) -> void:
	route.altar_action(action, id)
	_refresh_hud()
	_build()

func _retry_death() -> void:
	route.retry_death()
	_build()

func _complete() -> void:
	if route.complete_exploration().accepted:
		app.return_to_home()
	else:
		_build()

func _retry_growth() -> void:
	route._settle_growth()
	_build()

func close() -> void:
	if kind == "death" and route.session.pending_death:
		return
	modal.hide()
	kind = ""
	# UI 内的点击/移动不能在恢复时变成世界中的缓冲攻击或跳跃。
	for action in ["attack", "heavy_attack", "dodge", "jump", "move_left", "move_right", "interact", "heal"]:
		Input.action_release(action)
	route.player.attack_requested = false
	route.player.heavy_requested = false
	route.player.dodge_requested = false
	route.player.jump_remaining = 0
	app.set_modal_active(false)

func _input(event: InputEvent) -> void:
	if modal.visible and event.is_action_pressed("pause") and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()
