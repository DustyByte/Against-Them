extends Control

signal optionChosen

@onready var expBar: ProgressBar = $ProgressBar
@onready var fireButton: TextureButton = $FireButton
@onready var pauseButtonPanel: Panel =  $PauseButtonMarginContainer/Panel
@onready var _fireCenter: Control = $Control
@onready var _fireMat: ShaderMaterial = $Control/FireVisual.material
var _firePressTween: Tween
var _firePressed: float = 0.0     # current "pushed in" amount, mirrored to the shader
var _fireRippleTween: Tween

## Fire stick. A tap shoots once, right away, as a button. Dragging the knob
## aims by hand (the weapon and Echo point where it is pushed); pulled past the
## ring it keeps shooting at the weapon's own rate. Letting go returns to auto
## aim. Its look is fire_button.gdshader.
const FIRE_TOUCH_RADIUS: float = 86.0   # where a touch picks it up (as the old button)
const FIRE_RING_RADIUS: float = 82.0    # the ring (the shader's radius); past it = firing
const FIRE_AIM_DEADZONE: float = 14.0   # drag this far before it aims instead of tapping
var _fireFinger: int = -1
var _fireAiming: bool = false
var _fireShooting: bool = false
var _fireAimTween: Tween
var _fireAim: float = 0.0               # current aim look, mirrored to the shader
var _fireShootTween: Tween
var _fireShootLook: float = 0.0
var optionCardBluePrint: PackedScene = preload("res://Scenes/HUD/option_card.tscn")
var pauseMenu: Control = null
var activeOptionDisplay: OptionDisplay = null
var pendingOptionChoices: Array = []

func show_options(options: Array[Option]) -> void:
	if activeOptionDisplay != null:
		pendingOptionChoices.append(options)
		return
	
	get_tree().paused = true
	
	var optionDisplay: OptionDisplay = load("res://Scenes/HUD/option_display.tscn").instantiate()
	activeOptionDisplay = optionDisplay
	optionDisplay.on_select = send_selection_signal
	add_sibling(optionDisplay)
	optionDisplay.present_options(options)


func send_selection_signal(option: Option) -> void:
	optionChosen.emit(option)
	
	if activeOptionDisplay != null and is_instance_valid(activeOptionDisplay):
		activeOptionDisplay.queue_free()
	activeOptionDisplay = null
	
	if pendingOptionChoices.is_empty():
		get_tree().paused = false
		return
	
	var nextOptions: Array[Option] = pendingOptionChoices.pop_front()
	show_options(nextOptions)


func _ready() -> void:
	global.ON_RUN_HUD = self
	
	# Fire stick look (fire_button.gdshader); touches are handled in _input.
	_fireMat.set_shader_parameter("rect_size", $Control/FireVisual.size)
	
	var pauseButtonMinSize: Vector2 = Vector2.ONE * get_viewport_rect().size.y * 0.13
	pauseButtonPanel.custom_minimum_size = pauseButtonMinSize
	pauseButtonPanel.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.is_pressed():
			pauseMenu = preload("res://Scenes/HUD/pause_menu.tscn").instantiate()
			add_child(pauseMenu)
			get_tree().paused = true
	)


## Tints the fire button with the selected weapon's accent.
func set_fire_accent(color: Color) -> void:
	_fireMat.set_shader_parameter("accent", color)


# --- Fire stick ----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _fireFinger == -1 and not get_tree().paused 					and event.position.distance_to(_fire_center()) <= FIRE_TOUCH_RADIUS:
				_fireFinger = event.index
				_on_fire_pressed()
				global.PLAYERS_WEAPON_SYSTEM.shoot()   # a tap shoots right away, as before
		elif event.index == _fireFinger:
			_end_fire_stick()
	elif event is InputEventScreenDrag and event.index == _fireFinger:
		if get_tree().paused:
			_end_fire_stick()   # a choice screen opened mid-drag
			return
		var offset: Vector2 = event.position - _fire_center()
		var dist: float = offset.length()
		if not _fireAiming and dist < FIRE_AIM_DEADZONE:
			return
		if not _fireAiming:
			_fireAiming = true
			_tween_fire_aim(1.0, 0.12)
		var direction: Vector2 = offset / dist
		global.PLAYERS_WEAPON_SYSTEM.set_manual_aim(direction)
		_fireMat.set_shader_parameter("knob_offset", direction * minf(dist, FIRE_RING_RADIUS))
		_fireMat.set_shader_parameter("bullet_angle", direction.angle() + PI * 0.5)
		_set_fire_shooting(dist > FIRE_RING_RADIUS)


func _process(_delta: float) -> void:
	# Pulled past the ring: shoot whenever the weapon is ready (cooldown and
	# reloading are the weapon's own; shoot() reloads an empty magazine).
	if not _fireShooting or get_tree().paused:
		return
	var weaponSystem = global.PLAYERS_WEAPON_SYSTEM
	var w: Weapon = weaponSystem.weapon
	if w.cdRemainig or w.isReloading:
		return
	_fire_ripple()
	weaponSystem.shoot()


func _fire_center() -> Vector2:
	return _fireCenter.global_position


func _end_fire_stick() -> void:
	_fireFinger = -1
	_on_fire_released()
	_set_fire_shooting(false)
	if _fireAiming:
		_fireAiming = false
		_tween_fire_aim(0.0, 0.18)   # the knob eases back into the button
		global.PLAYERS_WEAPON_SYSTEM.clear_manual_aim()


func _set_fire_shooting(on: bool) -> void:
	if on == _fireShooting:
		return
	_fireShooting = on
	if _fireShootTween:
		_fireShootTween.kill()
	_fireShootTween = create_tween()
	_fireShootTween.tween_method(func(v: float):
		_fireShootLook = v
		_fireMat.set_shader_parameter("firing", v)
	, _fireShootLook, 1.0 if on else 0.0, 0.08 if on else 0.2)


func _tween_fire_aim(target: float, duration: float) -> void:
	if _fireAimTween:
		_fireAimTween.kill()
	_fireAimTween = create_tween()
	_fireAimTween.tween_method(func(v: float):
		_fireAim = v
		_fireMat.set_shader_parameter("aim", v)
	, _fireAim, target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_fire_pressed() -> void:
	_tween_fire_pressed(1.0, 0.06)
	_fire_ripple()


## Flash and ripple: on a press, and on every shot while the stick is firing.
func _fire_ripple() -> void:
	if _fireRippleTween:
		_fireRippleTween.kill()
	_fireRippleTween = create_tween()
	_fireRippleTween.tween_method(func(v: float): _fireMat.set_shader_parameter("ripple", v),
		0.0, 1.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_fire_released() -> void:
	_tween_fire_pressed(0.0, 0.18)


func _tween_fire_pressed(target: float, duration: float) -> void:
	if _firePressTween:
		_firePressTween.kill()
	_firePressTween = create_tween()
	_firePressTween.tween_method(func(v: float):
		_firePressed = v
		_fireMat.set_shader_parameter("pressed", v)
	, _firePressed, target, duration)
