extends RefCounted
const Ui := preload("res://scripts/ui/ui_style.gd")

static func portrait(body: Control, info: Dictionary) -> void:
	var image := TextureRect.new()
	image.texture = load(info.portrait)
	image.custom_minimum_size = Vector2(0, 110)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(image)
	Ui.label(body, "静态概念设定参考 · 世界角色与动作待制作", 14)
	var text := Ui.label(body, info.text, 17)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func build(ui: Control, id: String) -> void:
	var info: Dictionary = ui.route.services.characters[id]
	Ui.label(ui.body, info.name + " · " + info.role, 32)
	portrait(ui.body, info)
	match id:
		"shen_yan_zhou":
			Ui.button(ui.body, "练习基础剑术（无奖励木桩）", "NpcPractice", ui._npc.bind("practice"), ui)
		"gu_chang_geng":
			Ui.button(ui.body, "整理武器与装备", "NpcInventory", ui.open.bind("inventory", {}), ui)
			for item in ui.route.inventory.items:
				var button := Ui.button(ui.body, "登记蓝图 · " + item.name, "NpcBlueprint_" + str(ui.route.inventory.items.find(item)), ui._npc.bind("blueprint", item.item_id), ui)
				button.disabled = ui.route.session.profile.blueprints.has(item.item_id)
		"a_heng":
			var button := Ui.button(ui.body, "补齐随身药品（%d / 2）并保存探索" % ui.route.medicine, "NpcSupply", ui._npc.bind("supply"), ui)
			button.disabled = ui.route.medicine >= ui.route.services.medicine_capacity
