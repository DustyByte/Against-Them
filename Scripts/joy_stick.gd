class_name TouchScreenJoyStick
extends Node2D

var screenSize: Vector2 = Vector2.ZERO
var joyStickPosition: Vector2 = Vector2.ZERO
var knobPosition: Vector2 = Vector2.ZERO
var knobRadius: float = 0.0
@export var knobColor: Color = Color(1, 1, 1, 0.5)
var borderRadius: float = 0.0
@export var borderColor: Color = Color(1, 1, 1, 0.25)
@export var borderFill: bool = false
@export var fromLeft: float = 0.200
@export var fromTop: float = 0.666
var joyStickInputDeadZoneRadius: float = 0.0
var knobBeingHeld: bool = false

var output: Dictionary = {
	'direction' : Vector2.ZERO
}


func _ready() -> void:
	screenSize = get_viewport().get_visible_rect().size
	joyStickPosition = Vector2(screenSize.x * fromLeft, screenSize.y * fromTop)
	knobPosition = joyStickPosition
	knobRadius = get_window().size.y * 0.15 * 0.5
	borderRadius = knobRadius * 2
	joyStickInputDeadZoneRadius = borderRadius * 3


func _draw() -> void:
	draw_circle(to_local(joyStickPosition), borderRadius, borderColor, borderFill, 1, true)
	draw_circle(to_local(knobPosition), knobRadius, knobColor, true)


func is_inside_deadzone(pos: Vector2) -> bool:
	var touchToJSCenterDistanceSq: float = joyStickPosition.distance_squared_to(pos)
	return touchToJSCenterDistanceSq <= joyStickInputDeadZoneRadius * joyStickInputDeadZoneRadius


var JSFingerIndex: int = -1
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if JSFingerIndex == -1:
			if event.pressed and is_inside_deadzone(event.position):
				JSFingerIndex = event.index
				hold_knob(event.position)
		elif not event.pressed and JSFingerIndex == event.index:
			JSFingerIndex = -1
			release_knob()
	
	elif JSFingerIndex != -1 and event is InputEventScreenDrag:
		var JSToDragPointDirection := joyStickPosition.direction_to(event.position)
		var dragPointToJSCenterDistance := joyStickPosition.distance_to(event.position)
		
		output.direction = JSToDragPointDirection
		
		if dragPointToJSCenterDistance < borderRadius:
			move_knob(event.position)
		else:
			move_knob(joyStickPosition + (borderRadius * JSToDragPointDirection))
	
	
	elif event is InputEventMouseButton:
		if event.pressed:
			var touchToJSCenterDistance: float = joyStickPosition.distance_to(event.position)
			if touchToJSCenterDistance <= joyStickInputDeadZoneRadius:
				hold_knob(event.position)
		elif knobBeingHeld:
			release_knob()
	
	elif knobBeingHeld and event is InputEventMouseMotion:
		var JSToDragPointDirection := joyStickPosition.direction_to(event.position)
		var dragPointToJSCenterDistance := joyStickPosition.distance_to(event.position)
		
		output.direction = JSToDragPointDirection
		
		if dragPointToJSCenterDistance < borderRadius:
			move_knob(event.position)
		else:
			move_knob(joyStickPosition + (borderRadius * JSToDragPointDirection))


func hold_knob(holdingFrom: Vector2 = Vector2.ZERO) -> void:
	knobBeingHeld = true
	knobRadius += 10
	
	if holdingFrom:
		var touchToJSCenterDistance: float = joyStickPosition.distance_to(holdingFrom)
		var JSToTouchDirection: Vector2 = joyStickPosition.direction_to(holdingFrom)
		
		output.direction = JSToTouchDirection
		
		if touchToJSCenterDistance < borderRadius:
			move_knob(holdingFrom)
		else:
			move_knob(joyStickPosition + (borderRadius * JSToTouchDirection))
	
	queue_redraw()


func release_knob() -> void:
	knobBeingHeld = false
	knobRadius -= 10
	knobPosition = joyStickPosition
	output.direction = Vector2.ZERO
	queue_redraw()


func move_knob(to: Vector2) -> void:
	knobPosition = to
	queue_redraw()
