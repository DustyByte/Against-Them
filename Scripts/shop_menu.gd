extends "res://Scripts/tabbed_screen.gd"
## Shop screen: skins bought with Echoes, and utilities (Anchor Shards from ads).

const ANCHOR_SHARD_CARD: PackedScene = preload("res://Scenes/HUD/anchor_shard_card.tscn")
const SKIN_CARD: PackedScene = preload("res://Scenes/HUD/skin_card.tscn")
const CONFIRM_SCENE: PackedScene = preload("res://Scenes/HUD/upgrade_confirm.tscn")
const SkinData = preload("res://Scripts/skin_data.gd")

var _skin_cards: Array = []


## Add a name here to get a new tab and page.
func _tab_names() -> Array[String]:
	return ["Utilities", "Skins"]


func _populate() -> void:
	_populate_skins()
	_populate_utilities()
	MetaProgression.echoes_changed.connect(func(_total: int): _refresh_skin_cards())
	InventoryManager.skins_changed.connect(_refresh_skin_cards)


func _populate_skins() -> void:
	var grid: GridContainer = _grids["Skins"]
	for skin: Dictionary in SkinData.SKINS:
		var card := SKIN_CARD.instantiate()
		grid.add_child(card)
		card.setup(skin)
		card.preview_tapped.connect(func(id: String): _open_skin_viewer(SkinData.get_skin(id)))
		card.purchase_tapped.connect(_open_skin_purchase)
		_skin_cards.append(card)
	_fill_last_row(grid)


func _populate_utilities() -> void:
	var grid: GridContainer = _grids["Utilities"]
	grid.add_child(ANCHOR_SHARD_CARD.instantiate())
	_fill_last_row(grid)


func _refresh_skin_cards() -> void:
	for card in _skin_cards:
		card.refresh()


func _open_skin_purchase(skin_id: String) -> void:
	if _overlay != null or InventoryManager.owns_skin(skin_id):
		return
	_play_ui_sfx()
	var skin: Dictionary = SkinData.get_skin(skin_id)
	var dialog := CONFIRM_SCENE.instantiate()
	_show_overlay(dialog)
	dialog.setup_with_message(skin["name"], "Unlock this skin for Echo?", skin["price"], MetaProgression.echoes)
	dialog.cancelled.connect(func():
		_play_ui_sfx()
		_close_overlay()
	)
	dialog.confirmed.connect(func():
		_play_ui_sfx()
		InventoryManager.purchase_skin(skin_id, skin["price"])
		_close_overlay()
	)
