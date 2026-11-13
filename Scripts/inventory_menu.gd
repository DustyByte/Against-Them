extends "res://Scripts/tabbed_screen.gd"
## Inventory screen: items the player holds and the skins they own, where a
## skin can be previewed and equipped. Same layout as the Shop with a violet
## accent.

const ITEM_CARD: PackedScene = preload("res://Scenes/HUD/inventory_item_card.tscn")
const SKIN_CARD: PackedScene = preload("res://Scenes/HUD/inventory_skin_card.tscn")
const ItemData = preload("res://Scripts/item_data.gd")
const SkinData = preload("res://Scripts/skin_data.gd")

const VIOLET := Color(0.78, 0.64, 0.98)


func _tab_names() -> Array[String]:
	return ["Items", "Skins"]

func _accent() -> Color:
	return VIOLET

func _active_bg() -> Color:
	return Color(0.07, 0.06, 0.12, 0.92)   # same as the content panel

func _inactive_bg() -> Color:
	return Color(0.04, 0.035, 0.07, 0.75)


func _populate() -> void:
	_build_items()
	_build_skins()
	InventoryManager.anchor_shards_changed.connect(func(_total: int): _build_items())
	InventoryManager.skins_changed.connect(_build_skins)
	InventoryManager.equipped_skin_changed.connect(func(_id: String): _refresh_skins())


## Only items the player actually has are listed.
func _build_items() -> void:
	var grid: GridContainer = _grids["Items"]
	_clear_grid(grid)
	for item: Dictionary in ItemData.ITEMS:
		if InventoryManager.get_item_amount(item["id"]) <= 0:
			continue
		var card := ITEM_CARD.instantiate()
		grid.add_child(card)
		card.setup(item)
	if grid.get_child_count() == 0:
		grid.add_child(_empty_note("No items yet. Get them in the Shop."))
	_fill_last_row(grid)


## The default skin first, then every skin the player bought.
func _build_skins() -> void:
	var grid: GridContainer = _grids["Skins"]
	_clear_grid(grid)
	var ids: Array[String] = [SkinData.DEFAULT_SKIN["id"]]
	ids.append_array(InventoryManager.owned_skins())
	for skin_id in ids:
		var skin: Dictionary = SkinData.get_skin(skin_id)
		if skin.is_empty():
			continue
		var card := SKIN_CARD.instantiate()
		grid.add_child(card)
		card.setup(skin)
		card.preview_tapped.connect(func(id: String): _open_skin_viewer(SkinData.get_skin(id)))
		card.equip_tapped.connect(_on_equip_tapped)
	_fill_last_row(grid)


func _refresh_skins() -> void:
	for card in _grids["Skins"].get_children():
		if card.has_method("refresh"):
			card.refresh()


func _on_equip_tapped(skin_id: String) -> void:
	if _overlay != null or InventoryManager.equipped_skin == skin_id:
		return
	_play_ui_sfx()
	InventoryManager.equip_skin(skin_id)


func _empty_note(text: String) -> Label:
	var note := Label.new()
	note.text = text
	note.add_theme_font_override("font", TAB_FONT)
	note.add_theme_font_size_override("font_size", 20)
	note.add_theme_color_override("font_color", Color(VIOLET, 0.55))
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return note
