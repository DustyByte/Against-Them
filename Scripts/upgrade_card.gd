extends PanelContainer

## One upgrade in the Upgrades grid: icon, name, description, rank, a
## segmented bar with one block per rank (lit blocks = ranks already bought)
## and the Echoes cost of the next rank. Tapping the card emits `tapped`.

signal tapped(upgrade_id: String)

const BLOCK_LIT_COLOR: Color = Color(0.62, 0.88, 0.95, 1)
const BLOCK_UNLIT_COLOR: Color = Color(0.62, 0.88, 0.95, 0.1)
const BLOCK_UNLIT_BORDER: Color = Color(0.62, 0.88, 0.95, 0.25)

@onready var _placeholder: Label = $VBox/IconFrame/Placeholder
@onready var _icon: TextureRect = $VBox/IconFrame/Icon
@onready var _name_label: Label = $VBox/NameLabel
@onready var _desc_label: Label = $VBox/DescLabel
@onready var _rank_value: Label = $VBox/RankRow/RankValue
@onready var _blocks: HBoxContainer = $VBox/Blocks
@onready var _cost_icon: TextureRect = $VBox/CostPanel/HBox/CostIcon
@onready var _cost_value: Label = $VBox/CostPanel/HBox/CostValue
@onready var _cost_unit: Label = $VBox/CostPanel/HBox/CostUnit

const COST_AFFORDABLE_COLOR: Color = Color(0.94, 0.97, 1, 1)
const COST_UNAFFORDABLE_COLOR: Color = Color(0.95, 0.45, 0.45, 1)
## A touch that moves further than this is a scroll, not a tap.
const TAP_MAX_MOVE: float = 24.0

const NAME_FONT_SIZE: int = 24
const NAME_MIN_FONT_SIZE: int = 17
const NAME_LETTER_SPACING: int = 3

var upgrade_id: String = ""
var _name_base_font: Font
var _name_fonts: Dictionary = {} # letter spacing -> FontVariation
var _touch_start: Vector2
var _touch_active: bool = false


func _ready() -> void:
	var scene_font: Font = _name_label.get_theme_font("font")
	_name_base_font = scene_font.base_font if scene_font is FontVariation else scene_font
	_name_label.resized.connect(_fit_name)
	gui_input.connect(_on_gui_input)


## Tap = touch released close to where it started, so scrolling the list
## doesn't open the purchase dialog.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_touch_active = true
		elif _touch_active:
			_touch_active = false
			if event.position.distance_to(_touch_start) <= TAP_MAX_MOVE:
				tapped.emit(upgrade_id)
	elif event is InputEventScreenDrag and _touch_active:
		if event.position.distance_to(_touch_start) > TAP_MAX_MOVE:
			_touch_active = false


## Shows the cost in red when the player can't pay for the next rank.
func set_affordable(affordable: bool) -> void:
	_cost_value.add_theme_color_override("font_color", COST_AFFORDABLE_COLOR if affordable else COST_UNAFFORDABLE_COLOR)


## Long names ("Torcher: Lingering Flame") must fit the card width instead of
## being cut off: first the text gets smaller, then the letters move closer
## together, then it gets smaller again.
func _fit_name() -> void:
	var available: float = _name_label.size.x
	if available <= 0.0:
		return
	var text: String = _name_label.text

	var chosen_spacing: int = 0
	var chosen_size: int = NAME_MIN_FONT_SIZE
	var found: bool = false
	for spacing in range(NAME_LETTER_SPACING, -1, -1):
		for font_size in range(NAME_FONT_SIZE, NAME_MIN_FONT_SIZE - 1, -1):
			# Measure the plain font and add the extra letter spacing ourselves.
			var width: float = _name_base_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing * text.length()
			if width <= available:
				chosen_spacing = spacing
				chosen_size = font_size
				found = true
				break
		if found:
			break

	_name_label.add_theme_font_override("font", _get_name_font(chosen_spacing))
	_name_label.add_theme_font_size_override("font_size", chosen_size)


func _get_name_font(spacing: int) -> FontVariation:
	if not _name_fonts.has(spacing):
		var variation := FontVariation.new()
		variation.base_font = _name_base_font
		variation.spacing_glyph = spacing
		_name_fonts[spacing] = variation
	return _name_fonts[spacing]


## Call after the card is in the tree. `cost` is the price of the next rank.
## Pass `icon` = null to keep the placeholder.
func setup(id: String, title: String, description: String, rank: int, max_rank: int, cost: int, icon: Texture2D = null) -> void:
	upgrade_id = id
	_name_label.text = title.to_upper()
	_desc_label.text = description
	_fit_name()

	_placeholder.visible = icon == null
	_icon.visible = icon != null
	_icon.texture = icon

	set_rank(rank, max_rank, cost)


func set_rank(rank: int, max_rank: int, cost: int) -> void:
	rank = clampi(rank, 0, max_rank)
	_rank_value.text = "%d / %d" % [rank, max_rank]

	# At max rank there is nothing left to buy, so the cost becomes "MAXED".
	var maxed: bool = rank >= max_rank
	_cost_icon.visible = not maxed
	_cost_unit.visible = not maxed
	_cost_value.text = "MAXED" if maxed else str(cost)

	for child in _blocks.get_children():
		child.queue_free()
	for i in max_rank:
		_blocks.add_child(_make_block(i < rank))


func _make_block(lit: bool) -> Panel:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(2)
	if lit:
		style.bg_color = BLOCK_LIT_COLOR
	else:
		style.bg_color = BLOCK_UNLIT_COLOR
		style.set_border_width_all(1)
		style.border_color = BLOCK_UNLIT_BORDER

	var block := Panel.new()
	block.custom_minimum_size = Vector2(0, 10)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_stylebox_override("panel", style)
	return block
