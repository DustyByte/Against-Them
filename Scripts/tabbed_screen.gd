extends Control
## Shared base for the Shop and Inventory screens: a title, a row of
## browser-style tabs above one content panel, and a Home button. Each tab owns
## a scrollable 3-column grid of cards. Subclasses list their tabs, pick an
## accent colour and fill the grids in _populate().

signal returnPressed

const TAB_FONT: FontFile = preload("res://Resources/Copperplate.otf")
const TAB_SIZE := Vector2(230, 62)
const GRID_COLUMNS: int = 3

@onready var _tabs_row: HBoxContainer = $MarginContainer/VBoxContainer/BodyMargin/Body/Tabs
@onready var _content: PanelContainer = $MarginContainer/VBoxContainer/BodyMargin/Body/Content
@onready var _return_button: Panel = $MarginContainer/VBoxContainer/ReturnMargin/ReturnButton

var _tab_panels: Array[Panel] = []
var _pages: Array[Control] = []
var _grids: Dictionary = {}   # tab name -> GridContainer
var _current: int = -1
var _overlay: Control = null  # an open viewer or dialog; blocks tabs and Home


# --- Overridables -------------------------------------------------------------

func _tab_names() -> Array[String]:
	return []

func _accent() -> Color:
	return Color(0.62, 0.88, 0.95)

func _active_bg() -> Color:
	return Color(0.05, 0.1, 0.14, 0.92)   # same as the content panel

func _inactive_bg() -> Color:
	return Color(0.03, 0.06, 0.09, 0.75)

func _populate() -> void:
	pass


# --- Setup --------------------------------------------------------------------

func _ready() -> void:
	_return_button.gui_input.connect(_on_return_gui_input)
	# Draw tabs above the content panel so the active tab covers its top border.
	_tabs_row.z_index = 1
	var names := _tab_names()
	for i in names.size():
		_tab_panels.append(_make_tab(i, names[i]))
		_pages.append(_make_page(names[i]))
	_populate()
	_select_tab(0)


## A page is a scrollable grid of cards, 3 per row.
func _make_page(tab_name: String) -> Control:
	var page := MarginContainer.new()
	page.name = tab_name + "Page"
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	for side in ["left", "top", "right", "bottom"]:
		page.add_theme_constant_override("margin_" + side, 28)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	page.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(grid)

	_grids[tab_name] = grid
	_content.add_child(page)
	return page


## Removes every card from a grid (used before rebuilding it).
func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


## Empty cells so cards keep a third of the width even in a short last row.
func _fill_last_row(grid: GridContainer) -> void:
	var count: int = grid.get_child_count()
	while count % GRID_COLUMNS != 0:
		var filler := Control.new()
		filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(filler)
		count += 1


# --- Tabs ---------------------------------------------------------------------

func _make_tab(index: int, tab_name: String) -> Panel:
	var tab := Panel.new()
	tab.custom_minimum_size = TAB_SIZE

	var font := FontVariation.new()
	font.base_font = TAB_FONT
	font.spacing_glyph = 3
	var label := Label.new()
	label.name = "Label"
	label.text = tab_name.to_upper()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(label)

	tab.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.is_pressed() and index != _current and _overlay == null:
			_play_ui_sfx()
			_select_tab(index)
	)
	_tabs_row.add_child(tab)
	return tab


func _select_tab(index: int) -> void:
	_current = index
	var accent := _accent()
	for i in _tab_panels.size():
		var active: bool = i == index
		_tab_panels[i].add_theme_stylebox_override("panel", _tab_style(active))
		_tab_panels[i].get_node("Label").add_theme_color_override(
			"font_color", accent if active else Color(accent, 0.45))
		_pages[i].visible = active


## Active tab: content-panel colour, outlined on three sides with no bottom
## border, and stretched 2px down over the panel's top edge so the two read
## as one surface (like a browser tab).
func _tab_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	if active:
		style.bg_color = _active_bg()
		style.border_color = Color(_accent(), 0.55)
		style.expand_margin_bottom = 2
	else:
		style.bg_color = _inactive_bg()
		style.border_color = Color(_accent(), 0.18)
		style.border_width_bottom = 0
	return style


# --- Overlays (viewers, dialogs) ----------------------------------------------

func _show_overlay(overlay: Control) -> void:
	add_child(overlay)
	overlay.z_index = 2   # above the tab row (z 1)
	_overlay = overlay


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


## Opens the big skin viewer for a skin dictionary (see skin_data.gd).
func _open_skin_viewer(skin: Dictionary) -> void:
	if _overlay != null or skin.is_empty():
		return
	_play_ui_sfx()
	var viewer: Control = preload("res://Scripts/skin_viewer.gd").new()
	_show_overlay(viewer)
	viewer.setup(skin)
	viewer.closed.connect(func():
		_play_ui_sfx()
		_close_overlay()
	)


# --- Home button and sound ----------------------------------------------------

func _on_return_gui_input(event: InputEvent) -> void:
	if _overlay != null:
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
