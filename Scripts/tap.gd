class_name Tap
## Release-to-press for touch buttons. A tap counts when the finger lifts while
## still over the control and hasn't wandered far from where it touched down,
## so sliding off a button (or scrolling a list) cancels it.
##
##     func _on_gui_input(event):
##         if Tap.is_tap(self, event):
##             do_the_thing()

const MAX_DRIFT := 24.0
const _START := &"_tap_start"
const _INDEX := &"_tap_index"


static func is_tap(control: Control, event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			control.set_meta(_START, event.position)
			control.set_meta(_INDEX, event.index)
			return false
		if not is_held(control) or control.get_meta(_INDEX) != event.index:
			return false
		var start: Vector2 = control.get_meta(_START)
		control.remove_meta(_START)
		return event.position.distance_to(start) <= MAX_DRIFT \
			and Rect2(Vector2.ZERO, control.size).has_point(event.position)
	if event is InputEventScreenDrag and is_held(control) and control.get_meta(_INDEX) == event.index:
		if event.position.distance_to(control.get_meta(_START)) > MAX_DRIFT:
			control.remove_meta(_START)   # it's a drag now, not a tap
	return false


## True while a finger that touched down on `control` could still become a tap
## (use it for a pressed-down look).
static func is_held(control: Control) -> bool:
	return control.has_meta(_START)
