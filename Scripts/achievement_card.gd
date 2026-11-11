extends Panel

## Emitted when the player taps CLAIM on a completed, unclaimed achievement.
signal claim_requested(achievement_id: String)

const COLOR_ACCENT_LOCKED := Color(0.32, 0.36, 0.38, 1)
const COLOR_ACCENT_DONE := Color(0.95, 0.8, 0.42, 1)
const COLOR_ACCENT_CLAIMED := Color(0.45, 0.85, 0.88, 1)

@onready var _name_label: Label = $Margin/HBox/Info/NameLabel
@onready var _progress_bar: ProgressBar = $Margin/HBox/Info/ProgressRow/ProgressBar
@onready var _progress_label: Label = $Margin/HBox/Info/ProgressRow/ProgressLabel
@onready var _reward_amount: Label = $Margin/HBox/Reward/RewardVBox/RewardAmount
@onready var _type_badge: PanelContainer = $Margin/HBox/Info/ProgressRow/TypeBadge
@onready var _type_label: Label = $Margin/HBox/Info/ProgressRow/TypeBadge/TypeLabel
@onready var _claim_button: Panel = $Margin/HBox/ClaimButton
@onready var _claim_label: Label = $Margin/HBox/ClaimButton/ClaimLabel

var achievement_id: String = ""
var _current: int = 0
var _target: int = 1
var _claimed: bool = false

var _style_claim_disabled: StyleBoxFlat
var _style_claim_ready: StyleBoxFlat
var _style_claim_done: StyleBoxFlat


func _ready() -> void:
	# Each card owns its own copy so changing the accent of one card does not affect the others.
	add_theme_stylebox_override("panel", get_theme_stylebox("panel").duplicate())

	_style_claim_disabled = _make_claim_style(Color(0.22, 0.22, 0.23, 1), Color(0.3, 0.3, 0.32, 1))
	_style_claim_ready = _make_claim_style(Color(0.95, 0.8, 0.42, 1), Color(1, 0.93, 0.7, 1))
	_style_claim_done = _make_claim_style(Color(0.12, 0.2, 0.21, 1), Color(0.45, 0.85, 0.88, 0.6))

	_claim_button.gui_input.connect(_on_claim_gui_input)


func setup(id: String, title: String, is_lifetime: bool, current: int, target: int, reward: int, claimed: bool) -> void:
	achievement_id = id
	_set_type_badge(is_lifetime)
	_target = maxi(target, 1)
	_current = clampi(current, 0, _target)
	_claimed = claimed

	_name_label.text = title
	_reward_amount.text = str(reward)
	_progress_bar.max_value = _target
	_progress_bar.value = _current
	_progress_label.text = "%d/%d" % [_current, _target]
	_refresh_state()


func is_completed() -> bool:
	return _current >= _target


func set_claimed(claimed: bool) -> void:
	_claimed = claimed
	_refresh_state()


func _refresh_state() -> void:
	var panel_style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat

	if _claimed:
		_claim_label.text = "CLAIMED"
		_claim_label.add_theme_color_override("font_color", Color(0.45, 0.85, 0.88, 0.7))
		_claim_button.add_theme_stylebox_override("panel", _style_claim_done)
		panel_style.border_color = COLOR_ACCENT_CLAIMED
		modulate = Color(1, 1, 1, 0.75)
	elif is_completed():
		_claim_label.text = "CLAIM"
		_claim_label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1))
		_claim_button.add_theme_stylebox_override("panel", _style_claim_ready)
		panel_style.border_color = COLOR_ACCENT_DONE
		modulate = Color.WHITE
	else:
		_claim_label.text = "CLAIM"
		_claim_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		_claim_button.add_theme_stylebox_override("panel", _style_claim_disabled)
		panel_style.border_color = COLOR_ACCENT_LOCKED
		modulate = Color.WHITE


func _can_claim() -> bool:
	return is_completed() and not _claimed


func _on_claim_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed() and _can_claim():
		claim_requested.emit(achievement_id)


func _set_type_badge(is_lifetime: bool) -> void:
	# Run = must happen inside one descend (warm orange); Lifetime = adds up across descends (violet).
	var tint: Color = Color(0.72, 0.6, 0.95, 1) if is_lifetime else Color(0.95, 0.55, 0.35, 1)
	_type_label.text = "LIFETIME" if is_lifetime else "RUN"
	_type_label.add_theme_color_override("font_color", tint)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint, 0.12)
	style.border_color = Color(tint, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_type_badge.add_theme_stylebox_override("panel", style)


func _make_claim_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style
