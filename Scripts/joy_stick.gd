class_name TouchScreenJoyStick
extends Node2D

var screenSize: Vector2 = Vector2.ZERO
var joyStickPosition: Vector2 = Vector2.ZERO
var knobPosition: Vector2 = Vector2.ZERO
var knobRadius: float = 0.0
const JOYSTICK_SHADER: Shader = preload("res://Shaders/joystick.gdshader")
const VISUAL_PAD := 16.0          # room for the glows around the base and knob
var _visual: ColorRect
var _mat: ShaderMaterial
var _heldTween: Tween
var _held: float = 0.0            # current "held" look, mirrored to the shader
# Resting size; the knob grows by KNOB_HELD_GROWTH while held. Set, never
# added to, so uneven press/release pairs can't make it drift.
var knobBaseRadius: float = 0.0
const KNOB_HELD_GROWTH := 10.0
var borderRadius: float = 0.0
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
	knobBaseRadius = get_window().size.y * 0.15 * 0.5
	knobRadius = knobBaseRadius
	borderRadius = knobBaseRadius * 2
	joyStickInputDeadZoneRadius = borderRadius * 3
	_build_visual()


## The joystick is drawn by joystick.gdshader on one rect centered on the base.
## It only changes when the touch does, so there is no per-frame work.
func _build_visual() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = JOYSTICK_SHADER
	_visual = ColorRect.new()
	_visual.material = _mat
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var half: float = borderRadius + knobBaseRadius + KNOB_HELD_GROWTH + VISUAL_PAD
	_visual.size = Vector2.ONE * half * 2.0
	_visual.position = to_local(joyStickPosition) - _visual.size * 0.5
	add_child(_visual)
	_mat.set_shader_parameter("rect_size", _visual.size)
	_mat.set_shader_parameter("base_radius", borderRadius)
	_mat.set_shader_parameter("held", 0.0)
	_update_visual()


func _update_visual() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("knob_radius", knobRadius)
	_mat.set_shader_parameter("knob_offset", knobPosition - joyStickPosition)


## Eases the "held" look in or out.
func _set_held_look(on: bool) -> void:
	if _mat == null:
		return
	if _heldTween:
		_heldTween.kill()
	_heldTween = create_tween()
	_heldTween.tween_method(func(v: float):
		_held = v
		_mat.set_shader_parameter("held", v)
	, _held, 1.0 if on else 0.0, 0.12 if on else 0.25)


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
	
	
	# On phones every touch is also sent as a fake mouse event; touches are
	# already handled above, so only real mice (desktop testing) go below.
	elif event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	
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
	knobRadius = knobBaseRadius + KNOB_HELD_GROWTH
	
	if holdingFrom:
		var touchToJSCenterDistance: float = joyStickPosition.distance_to(holdingFrom)
		var JSToTouchDirection: Vector2 = joyStickPosition.direction_to(holdingFrom)
		
		output.direction = JSToTouchDirection
		
		if touchToJSCenterDistance < borderRadius:
			move_knob(holdingFrom)
		else:
			move_knob(joyStickPosition + (borderRadius * JSToTouchDirection))
	
	_set_held_look(true)
	_update_visual()


func release_knob() -> void:
	knobBeingHeld = false
	knobRadius = knobBaseRadius
	knobPosition = joyStickPosition
	output.direction = Vector2.ZERO
	_set_held_look(false)
	_update_visual()


func move_knob(to: Vector2) -> void:
	knobPosition = to
	_update_visual()
