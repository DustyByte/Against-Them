extends Control

signal optionChosen

@onready var expBar: ProgressBar = $ProgressBar
@onready var fireButton: TextureButton = $FireButton
@onready var pauseButtonPanel: Panel =  $PauseButtonMarginContainer/Panel
var optionCardBluePrint: PackedScene = preload("res://Scenes/HUD/option_card.tscn")
var pauseMenu: Control = null

func show_options(options: Array[Option]) -> void:
	var optionDisplay: OptionDisplay = load("res://Scenes/HUD/option_display.tscn").instantiate()
	optionDisplay.on_select = send_selection_signal
	add_sibling(optionDisplay)
	optionDisplay.present_options(options)


func send_selection_signal(option: Option) -> void:
	optionChosen.emit(option)
	get_tree().paused = false


func _ready() -> void:
	global.ON_RUN_HUD = self
	
	var pauseButtonMinSize: Vector2 = Vector2.ONE * get_viewport_rect().size.y * 0.13
	pauseButtonPanel.custom_minimum_size = pauseButtonMinSize
	pauseButtonPanel.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.is_pressed():
			pauseMenu = preload("res://Scenes/HUD/pause_menu.tscn").instantiate()
			add_child(pauseMenu)
			get_tree().paused = true
	)
