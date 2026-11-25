class_name UnlockPips
extends Control

## A row of small dots under an option's "unlocks" icon on the level-up card:
## how many picks of the option have been made towards opening it. Filled =
## done, bright empty ring = the pick being offered now, faint ring = still to
## go. Only shown when it takes more than one pick.

const DOT_RADIUS: float = 9.0
const GAP: float = 8.0
const FILLED: Color = Color(0.80, 0.70, 1.0, 1.0)
const NEXT: Color = Color(0.80, 0.70, 1.0, 0.9)
const LATER: Color = Color(0.80, 0.70, 1.0, 0.35)

var done: int = 0
var needed: int = 1


func setup(picks_done: int, picks_needed: int) -> void:
	done = picks_done
	needed = picks_needed
	custom_minimum_size = Vector2(needed * DOT_RADIUS * 2.0 + (needed - 1) * GAP, DOT_RADIUS * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	for i in needed:
		var c := Vector2(DOT_RADIUS + i * (DOT_RADIUS * 2.0 + GAP), DOT_RADIUS)
		if i < done:
			draw_circle(c, DOT_RADIUS, FILLED)
		elif i == done:
			draw_arc(c, DOT_RADIUS - 2.0, 0.0, TAU, 24, NEXT, 3.5, true)
		else:
			draw_arc(c, DOT_RADIUS - 1.5, 0.0, TAU, 20, LATER, 2.0, true)
