class_name AvatarPortrait
extends Panel

## A profile portrait: the avatar's art inside a rounded frame tinted per
## avatar. Avatars without art show a "?" instead. Scales with its size.
## The art files have the same rounded corners baked in (22% of the side).

const FONT := preload("res://Resources/Copperplate.otf")
const CORNER_RATIO := 0.22

@export var avatar: int = 0:
	set(value):
		avatar = value
		_refresh()

## Thicker, brighter frame (used for the selected option in the picker).
@export var highlighted: bool = false:
	set(value):
		highlighted = value
		_refresh()

var _art: TextureRect
var _label: Label
var _frame: Panel
var _style := StyleBoxFlat.new()          # background behind the art
var _frame_style := StyleBoxFlat.new()    # border, drawn over the art


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", _style)

	_art = TextureRect.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art, false, Node.INTERNAL_MODE_FRONT)

	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = "?"
	_label.add_theme_font_override("font", FONT)
	add_child(_label, false, Node.INTERNAL_MODE_FRONT)

	_frame = Panel.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_style.draw_center = false
	_frame.add_theme_stylebox_override("panel", _frame_style)
	add_child(_frame, false, Node.INTERNAL_MODE_FRONT)

	resized.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if _frame == null:
		return
	var entry: Dictionary = _entry()
	var tint: Color = entry.get("tint", Color(0.62, 0.88, 0.95))
	var texture: Texture2D = entry.get("texture")
	var side: float = minf(size.x, size.y)
	var radius := int(side * CORNER_RATIO)

	_art.texture = texture
	_art.visible = texture != null
	_label.visible = texture == null

	var bg_strength := 0.24 if highlighted else 0.16
	_style.bg_color = Color(tint.r * bg_strength, tint.g * bg_strength, tint.b * (bg_strength + 0.04), 1.0)
	_style.set_corner_radius_all(radius)

	_frame_style.border_color = Color(tint, 1.0 if highlighted else 0.6)
	_frame_style.set_border_width_all(3 if highlighted else maxi(1, int(side / 40.0)))
	_frame_style.set_corner_radius_all(radius)

	_label.add_theme_font_size_override("font_size", int(side * 0.52))
	_label.add_theme_color_override("font_color", tint.lightened(0.2))


func _entry() -> Dictionary:
	var avatars: Array = PlayerProfile.AVATARS
	if avatar >= 0 and avatar < avatars.size():
		return avatars[avatar]
	return {}
