extends Control

signal returnPressed

const UPGRADE_CARD_SCENE: PackedScene = preload("res://Scenes/HUD/upgrade_card.tscn")
const CONFIRM_SCENE: PackedScene = preload("res://Scenes/HUD/upgrade_confirm.tscn")
const UpgradeData = preload("res://Scripts/upgrade_data.gd")
const HEADER_FONT: FontFile = preload("res://Resources/Copperplate.otf")
const GRID_COLUMNS: int = 4
## Each upgrade's icon is <upgrade id>.svg in this folder; cards without one
## keep the "?" placeholder.
const ICON_FOLDER: String = "res://Assets/HUD Elements/UpgradeIcons/"

@onready var _sections: VBoxContainer = $MarginContainer/VBoxContainer/ListMargin/ScrollContainer/Sections
@onready var _return_button: Panel = $MarginContainer/VBoxContainer/ReturnMargin/ReturnButton

var _cards: Dictionary = {} # upgrade id -> card
var _confirm_dialog: Control = null


func _ready() -> void:
	_return_button.gui_input.connect(_on_return_gui_input)
	_build_cards()
	MetaProgression.echoes_changed.connect(func(_total: int): _refresh_affordability())


## One heading plus a 4-column grid per category.
func _build_cards() -> void:
	for category: String in UpgradeData.CATEGORIES:
		_sections.add_child(_make_category_header(category))

		var grid := GridContainer.new()
		grid.columns = GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 20)
		grid.mouse_filter = Control.MOUSE_FILTER_PASS
		_sections.add_child(grid)

		var count: int = 0
		for upgrade: Dictionary in UpgradeData.UPGRADES:
			if upgrade["category"] != category:
				continue
			var upgrade_id: String = upgrade["id"]
			var card := UPGRADE_CARD_SCENE.instantiate()
			grid.add_child(card)
			card.setup(
				upgrade_id,
				upgrade["title"],
				upgrade["description"],
				UpgradeManager.get_rank(upgrade_id),
				upgrade["max_rank"],
				UpgradeManager.get_next_cost(upgrade_id),
				_load_icon(upgrade_id)
			)
			card.tapped.connect(_on_card_tapped)
			_cards[upgrade_id] = card
			count += 1

		# Fill the last row with empty cells so cards keep the same width
		# even when a category has fewer than four upgrades.
		while count % GRID_COLUMNS != 0:
			var filler := Control.new()
			filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(filler)
			count += 1


	_refresh_affordability()


func _load_icon(upgrade_id: String) -> Texture2D:
	var path: String = ICON_FOLDER + upgrade_id + ".svg"
	return load(path) if ResourceLoader.exists(path) else null


func _refresh_affordability() -> void:
	for upgrade_id: String in _cards:
		_cards[upgrade_id].set_affordable(UpgradeManager.is_maxed(upgrade_id) or UpgradeManager.can_afford(upgrade_id))


# --- Purchasing --------------------------------------------------------------

func _on_card_tapped(upgrade_id: String) -> void:
	if _confirm_dialog != null or UpgradeManager.is_maxed(upgrade_id):
		return
	_play_ui_sfx()

	var upgrade: Dictionary = _find_upgrade(upgrade_id)
	_confirm_dialog = CONFIRM_SCENE.instantiate()
	add_child(_confirm_dialog)
	_confirm_dialog.setup(
		upgrade["title"],
		UpgradeManager.get_rank(upgrade_id) + 1,
		upgrade["max_rank"],
		UpgradeManager.get_next_cost(upgrade_id),
		MetaProgression.echoes
	)
	_confirm_dialog.cancelled.connect(func():
		_play_ui_sfx()
		_close_confirm_dialog()
	)
	_confirm_dialog.confirmed.connect(func():
		_play_ui_sfx()
		if UpgradeManager.purchase(upgrade_id):
			_cards[upgrade_id].set_rank(
				UpgradeManager.get_rank(upgrade_id),
				upgrade["max_rank"],
				UpgradeManager.get_next_cost(upgrade_id)
			)
			_refresh_affordability()
		_close_confirm_dialog()
	)


func _close_confirm_dialog() -> void:
	if _confirm_dialog != null:
		_confirm_dialog.queue_free()
		_confirm_dialog = null


func _find_upgrade(upgrade_id: String) -> Dictionary:
	for upgrade: Dictionary in UpgradeData.UPGRADES:
		if upgrade["id"] == upgrade_id:
			return upgrade
	return {}


func _make_category_header(category: String) -> Control:
	var font := FontVariation.new()
	font.base_font = HEADER_FONT
	font.spacing_glyph = 4

	var header := Label.new()
	header.text = category.to_upper()
	header.add_theme_font_override("font", font)
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.62, 0.88, 0.95, 1))

	# Extra space above each heading so categories read as separate groups.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_left", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(header)
	return margin


func _on_return_gui_input(event: InputEvent) -> void:
	if _confirm_dialog != null:
		return
	if event is InputEventScreenTouch and event.is_pressed():
		_play_ui_sfx()
		returnPressed.emit()


func _play_ui_sfx() -> void:
	if global.SFX_TYPES_PERM["ui"]:
		var asp := AudioStreamPlayer.new()
		asp.stream = preload("res://Assets/SFX/UI.mp3")
		asp.pitch_scale = randf_range(0.7, 1.3)
		# Parented to the global autoload so the sound survives this screen being freed on return.
		global.add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)
