extends Control

## Leaderboards screen, opened from the button beside the Home profile notch.
## A full screen like Upgrades and Achievements (title, content, Home button).
## One tab per board (see Leaderboards.BOARDS), each listing the top 100 players
## with their portrait, name and value. Tapping a player opens their profile card.
##
## Kept light: a tab's rows are built the first time it's shown and then kept,
## the boards come from one small request (cached for a while by Leaderboards).

signal returnPressed

const ProfileCard := preload("res://Scripts/profile_card.gd")
const FONT := preload("res://Resources/Copperplate.otf")

const ACCENT := Color(0.62, 0.88, 0.95)
const ROW_HEIGHT := 64.0
const AVATAR_SIZE := Vector2(48, 48)
const RANK_COLORS: Array[Color] = [
	Color(0.98, 0.82, 0.4),    # gold
	Color(0.86, 0.9, 0.96),    # silver
	Color(0.9, 0.62, 0.4),     # bronze
]
const RANK_COLOR := Color(0.55, 0.7, 0.78, 0.9)

@onready var _tabs: HBoxContainer = $MarginContainer/VBoxContainer/ContentMargin/VBox/Tabs
@onready var _scroll: ScrollContainer = $MarginContainer/VBoxContainer/ContentMargin/VBox/ListFrame/Scroll
@onready var _lists: VBoxContainer = $MarginContainer/VBoxContainer/ContentMargin/VBox/ListFrame/Scroll/Lists
@onready var _status: Label = $MarginContainer/VBoxContainer/ContentMargin/VBox/ListFrame/Status
@onready var _return_btn: Panel = $MarginContainer/VBoxContainer/ReturnMargin/ReturnButton

var _home: Node
var _on_tap: Callable   # home.gd's tap handler: plays the menu sound, then runs the action
var _boards: Dictionary = {}
var _tab := 0
var _built: Dictionary = {}   # board id -> its VBoxContainer of rows
var _loading := false

var _tab_style := _box(0.035, 0.16)
var _tab_style_on := _box(0.16, 0.8)
var _row_style := _box(0.03, 0.08)
var _row_style_you := _box(0.12, 0.6)
## Top three rows: gold, silver and copper border and fill (your own row too,
## if you're up there).
var _row_style_podium: Array[StyleBoxFlat] = [_podium_box(0), _podium_box(1), _podium_box(2)]


func _ready() -> void:
	_home = $"../.."
	_on_tap = _home._check_if_touch_then_execute
	_build_tabs()
	_return_btn.gui_input.connect(_on_tap.bind(_return_btn, func(): returnPressed.emit()))
	_status.gui_input.connect(_on_tap.bind(_status, _load))   # tap to retry
	_load()


func _build_tabs() -> void:
	for i in Leaderboards.BOARDS.size():
		var tab := Panel.new()
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		label.text = Leaderboards.BOARDS[i].title
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 19)
		tab.add_child(label)
		_tabs.add_child(tab)
		tab.gui_input.connect(_on_tap.bind(tab, _select_tab.bind(i)))
	_style_tabs()


func _style_tabs() -> void:
	for i in _tabs.get_child_count():
		var tab: Panel = _tabs.get_child(i)
		var on := i == _tab
		tab.add_theme_stylebox_override("panel", _tab_style_on if on else _tab_style)
		tab.get_child(0).add_theme_color_override("font_color",
			Color(0.96, 0.97, 1) if on else Color(0.62, 0.72, 0.8))


func _select_tab(index: int) -> void:
	if index == _tab:
		return
	_tab = index
	_style_tabs()
	_show_board()


func _load() -> void:
	if _loading:
		return
	_loading = true
	_set_status("LOADING...", false)
	_boards = await Leaderboards.get_boards()
	_loading = false
	if not is_inside_tree():
		return
	if _boards.is_empty():
		_set_status("COULDN'T REACH THE SERVER\n\nTAP TO TRY AGAIN", true)
		return
	_show_board()


func _show_board() -> void:
	if _boards.is_empty():
		return
	var board: Dictionary = Leaderboards.BOARDS[_tab]
	var entries: Array = _boards.get(board.id, [])
	if not _built.has(board.id):
		_built[board.id] = _build_list(entries, board.get("time", false))
	for list: Control in _lists.get_children():
		list.visible = list == _built[board.id]
	_scroll.scroll_vertical = 0
	if entries.is_empty():
		_set_status("NO DESCENTS RECORDED YET", false)
	else:
		_status.visible = false


func _set_status(text: String, tappable: bool) -> void:
	_status.text = text
	_status.visible = true
	_status.mouse_filter = Control.MOUSE_FILTER_STOP if tappable else Control.MOUSE_FILTER_IGNORE
	for list: Control in _lists.get_children():
		list.visible = false


func _build_list(entries: Array, is_time: bool) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_theme_constant_override("separation", 6)
	for i in entries.size():
		list.add_child(_build_row(i + 1, entries[i], is_time))
	_lists.add_child(list)
	return list


func _build_row(rank: int, entry: Dictionary, is_time: bool) -> Control:
	var you: bool = str(entry.get("id", "")) == PlayerProfile.player_id
	var row := PanelContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	row.mouse_filter = Control.MOUSE_FILTER_PASS   # lets the list scroll from a drag
	var style: StyleBoxFlat = _row_style_you if you else _row_style
	if rank <= _row_style_podium.size():
		style = _row_style_podium[rank - 1]
	row.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 18)
	row.add_child(hbox)

	var rank_label := _label(str(rank), 24, RANK_COLORS[rank - 1] if rank <= 3 else RANK_COLOR)
	rank_label.custom_minimum_size.x = 58
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(rank_label)

	var portrait := AvatarPortrait.new()
	portrait.custom_minimum_size = AVATAR_SIZE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.avatar = int(entry.get("avatar", 0))
	hbox.add_child(portrait)

	var name_label := _label(str(entry.get("name", "")), 22, Color(0.96, 0.97, 1) if you else Color(0.86, 0.9, 0.95))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(name_label)

	var value_label := _label(ProfileCard.format_stat(int(entry.get("value", 0)), is_time), 24, ACCENT.lightened(0.25))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 150
	hbox.add_child(value_label)

	row.gui_input.connect(_on_tap.bind(row, _home.show_player_profile.bind(entry)))
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Dark navy (as the Upgrades cards) tinted towards the accent by `bg_alpha`,
## nearly opaque so the planet behind doesn't show through the text.
static func _box(bg_alpha: float, border_alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.05, 0.075).lerp(ACCENT, bg_alpha)
	box.bg_color.a = 0.94
	box.border_color = Color(ACCENT, border_alpha)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12
	box.content_margin_right = 22
	return box


## Navy tinted with the medal colour, edged in it.
static func _podium_box(place: int) -> StyleBoxFlat:
	var medal: Color = RANK_COLORS[place]
	var box := _box(0.0, 0.0)
	box.bg_color = Color(0.035, 0.05, 0.075).lerp(medal, 0.2)
	box.bg_color.a = 0.94
	box.border_color = Color(medal, 0.9)
	box.set_border_width_all(2)
	return box
