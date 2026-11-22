class_name NotifyDot
extends Control

## A small red dot that pulses to say "something here wants your attention".
## Put it next to a button and toggle `visible`; it only animates while shown.

const COLOR := Color(1.0, 0.3, 0.36)
const RADIUS: float = 5.5
const PULSE_TIME: float = 1.3

var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(RADIUS, RADIUS) * 6.0
	size = custom_minimum_size


func _process(delta: float) -> void:
	_t = fmod(_t + delta, PULSE_TIME)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(is_visible_in_tree())


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var k: float = _t / PULSE_TIME
	# A ring swelling out and fading, over a dot that breathes slightly.
	draw_circle(c, RADIUS * (1.0 + 1.6 * k), Color(COLOR, 0.45 * (1.0 - k)))
	draw_circle(c, RADIUS * (1.0 + 0.12 * sin(TAU * k)), COLOR)
