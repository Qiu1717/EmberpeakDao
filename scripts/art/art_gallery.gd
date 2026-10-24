extends Control
const Ui := preload("res://scripts/ui/ui_style.gd")
const Catalog := preload("res://scripts/art/art_catalog.gd")
var items: ItemList
var preview: TextureRect
var caption: Label
var description: Label
var filtered: Array = []
var current_entry: Dictionary

func _ready() -> void:
	get_node("/root/App").enter_menu()
	theme = Ui.theme()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Ui.label(header, "无名剑冢 · 美术图鉴", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.button(header, "返回主菜单", "Back", get_node("/root/App").return_to_menu, self)
	var note := Ui.label(column, "26张现有原图｜首图已接NPC服务、装备和可走地图；本页为静态参考，正式动作与建筑拆件待制作。", 16)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 220
	body.add_child(sidebar)
	var category := OptionButton.new()
	category.name = "Category"
	for text in ["全部", "主角", "敌人", "NPC", "武器装备", "场景"]:
		category.add_item(text)
	category.item_selected.connect(func(index: int): select_category(category.get_item_text(index)))
	sidebar.add_child(category)
	items = ItemList.new()
	items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items.item_selected.connect(_show_entry)
	sidebar.add_child(items)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(detail)
	caption = Ui.label(detail, "", 24)
	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	detail.add_child(preview)
	description = Ui.label(detail, "", 16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	select_category("全部")
	category.grab_focus()

func select_category(category: String) -> void:
	items.clear()
	filtered.clear()
	for item: Dictionary in Catalog.entries():
		if category == "全部" or item.category == category:
			filtered.append(item)
			items.add_item(item.title)
	items.select(0)
	_show_entry(0)

func _show_entry(index: int) -> void:
	current_entry = filtered[index]
	preview.texture = load(current_entry.path)
	caption.text = current_entry.title + " · " + current_entry.category
	description.text = current_entry.description

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		get_node("/root/App").return_to_menu()
		get_viewport().set_input_as_handled()
