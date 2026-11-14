extends Control

signal optionChosen

@onready var expBar: ProgressBar = $ProgressBar
@onready var fireButton: TextureButton = $FireButton
@onready var pauseButtonPanel: Panel =  $PauseButtonMarginContainer/Panel
@onready var _fireButton: TouchScreenButton = $Control/TouchScreenButton
@onready var _fireMat: ShaderMaterial = $Control/FireVisual.material
var _firePressTween: Tween
var _firePressed: float = 0.0     # current "pushed in" amount, mirrored to the shader
var _fireRippleTween: Tween
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
	
	# Fire button look (fire_button.gdshader); the touch area is unchanged.
	_fireMat.set_shader_parameter("rect_size", $Control/FireVisual.size)
	_fireButton.pressed.connect(_on_fire_pressed)
	_fireButton.released.connect(_on_fire_released)
	
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


func _on_fire_pressed() -> void:
	_tween_fire_pressed(1.0, 0.06)
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
