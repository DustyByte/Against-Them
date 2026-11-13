extends Control
## Full-screen overlay showing one skin large: the live preview, the skin's
## name, and Idle / Run buttons to see it in motion. Tap Close or anywhere
## outside the panel to dismiss.

signal closed

const SkinPreview = preload("res://Scripts/skin_preview.gd")
const FONT: FontFile = preload("res://Resources/Copperplate.otf")
const ACCENT := Color(0.62, 0.88, 0.95)
const PREVIEW_SIZE := Vector2(560, 560)

var _shader: Shader
var _preview: SubViewportContainer
var _preview_slot: PanelContainer
var _mode_buttons: Dictionary = {}   # animation name -> Panel


func setup(skin: Dictionary) -> void:
	_shader = load(skin["shader"]) if skin.get("shader", "") != "" else null
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_close_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.035, 0.05, 0.075, 0.97), Color(ACCENT, 0.35), 12, 28))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)

	column.add_child(_label(String(skin["name"]).to_upper(), 34, Color(0.93, 0.96, 1), 4))

	_preview_slot = PanelContainer.new()
	_preview_slot.custom_minimum_size = PREVIEW_SIZE
	_preview_slot.add_theme_stylebox_override("panel", _box(Color(ACCENT, 0.04), Color(ACCENT, 0.25), 10, 0))
	column.add_child(_preview_slot)
	_show_animation("idle")

	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 14)
	column.add_child(modes)
	for anim in ["idle", "run"]:
		var b := _button(anim.to_upper(), Vector2(150, 50))
		b.gui_input.connect(func(event: InputEvent):
			if event is InputEventScreenTouch and event.is_pressed():
				_show_animation(anim))
		modes.add_child(b)
		_mode_buttons[anim] = b
	_highlight_mode("idle")

	var close := _button("CLOSE", Vector2(0, 60))
	close.gui_input.connect(_on_close_input)
	column.add_child(close)


func _show_animation(anim: String) -> void:
	if _preview != null:
		_preview.queue_free()
	_preview = SkinPreview.new()
	_preview.setup(_shader, anim)
	_preview_slot.add_child(_preview)
	_highlight_mode(anim)


func _highlight_mode(anim: String) -> void:
	for key in _mode_buttons:
		_mode_buttons[key].modulate.a = 1.0 if key == anim else 0.45


func _on_close_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		accept_event()
		closed.emit()


# --- Small builders -----------------------------------------------------------

func _box(bg: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


func _label(text: String, size_px: int, color: Color, spacing: int = 3) -> Label:
	var font := FontVariation.new()
	font.base_font = FONT
	font.spacing_glyph = spacing
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, min_size: Vector2) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = min_size
	p.add_theme_stylebox_override("panel", _box(Color(ACCENT, 0.14), Color(ACCENT, 0.7), 8, 0))
	var l := _label(text, 20, Color(0.85, 0.96, 1))
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(l)
	return p
