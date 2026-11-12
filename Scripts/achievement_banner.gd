extends Control

## "Achievement Unlocked!" banner shown during a run.
## Animation: drops in from above with a small overshoot while fading in,
## a light streak sweeps across it and the gold glow pulses, it holds,
## then it lifts up and fades out. Emits `finished` just before freeing itself.

signal finished

## Vertical position of the banner's top edge, as a fraction of screen height.
## Above the wave banner (0.25) so the two never overlap.
@export_range(0.0, 1.0, 0.001) var screen_position_y: float = 0.08

const ENTER_TIME: float = 0.45
const HOLD_TIME: float = 2.2
const EXIT_TIME: float = 0.3
const DROP_DISTANCE: float = 50.0
const LIFT_DISTANCE: float = 30.0

@onready var _body: Panel = $Body
@onready var _shine: Polygon2D = $Body/Shine
@onready var _title: Label = $Body/Margin/HBox/Text/Title
@onready var _amount: Label = $Body/Margin/HBox/Reward/Amount


func setup(title: String, reward: int) -> void:
	_title.text = title
	_amount.text = "+%d" % reward


func play() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var rest_position := Vector2((screen.x - size.x) * 0.5, screen.y * screen_position_y)

	position = rest_position - Vector2(0.0, DROP_DISTANCE)
	scale = Vector2(0.85, 0.85)
	modulate.a = 0.0
	_shine.position.x = -120.0

	# Own copy so the glow pulse doesn't change the shared resource.
	var body_style: StyleBoxFlat = _body.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_body.add_theme_stylebox_override("panel", body_style)
	var base_glow: int = body_style.shadow_size

	# Enter
	var enter := create_tween().set_parallel()
	enter.tween_property(self, "position", rest_position, ENTER_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter.tween_property(self, "scale", Vector2.ONE, ENTER_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter.tween_property(self, "modulate:a", 1.0, ENTER_TIME * 0.6)
	await enter.finished

	# Shine sweep + glow pulse, during the hold
	var accent := create_tween().set_parallel()
	accent.tween_property(_shine, "position:x", size.x + 40.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	accent.tween_property(body_style, "shadow_size", base_glow + 14, 0.35).set_trans(Tween.TRANS_SINE)
	accent.chain().tween_property(body_style, "shadow_size", base_glow, 0.5).set_trans(Tween.TRANS_SINE)

	var hold := create_tween()
	hold.tween_interval(HOLD_TIME)
	await hold.finished

	# Exit
	var exit := create_tween().set_parallel()
	exit.tween_property(self, "position:y", rest_position.y - LIFT_DISTANCE, EXIT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_property(self, "modulate:a", 0.0, EXIT_TIME)
	await exit.finished

	finished.emit()
	queue_free()
