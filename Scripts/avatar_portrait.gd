class_name AvatarPortrait
extends Panel

## A profile portrait: a rounded frame tinted per avatar, showing the avatar's
## picture (a "?" placeholder until the art exists). Scales with its size.

const FONT := preload("res://Resources/Copperplate.otf")

@export var avatar: int = 0:
	set(value):
		avatar = value
		_refresh()

## Thicker, brighter frame (used for the selected option in the picker).
@export var highlighted: bool = false:
	set(value):
		highlighted = value
		_refresh()

var _label: Label
var _style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = "?"
	_label.add_theme_font_override("font", FONT)
	add_child(_label, false, Node.INTERNAL_MODE_FRONT)
	add_theme_stylebox_override("panel", _style)
	resized.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	var tint: Color = _tint()
	var side: float = minf(size.x, size.y)
	var radius := int(side * 0.22)
	_style.bg_color = Color(tint.r * (0.24 if highlighted else 0.16), tint.g * (0.24 if highlighted else 0.16), tint.b * (0.28 if highlighted else 0.2), 1.0)
	_style.border_color = Color(tint, 1.0 if highlighted else 0.6)
	_style.set_border_width_all(3 if highlighted else maxi(1, int(side / 40.0)))
	_style.set_corner_radius_all(radius)
	_label.add_theme_font_size_override("font_size", int(side * 0.52))
	_label.add_theme_color_override("font_color", tint.lightened(0.2))


func _tint() -> Color:
	var avatars: Array = PlayerProfile.AVATARS
	if avatar >= 0 and avatar < avatars.size():
		return avatars[avatar].tint
	return Color(0.62, 0.88, 0.95)
