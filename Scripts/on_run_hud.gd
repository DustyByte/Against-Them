extends Control

signal optionChosen

@onready var expBar: ProgressBar = $ProgressBar
@onready var fireButton: TextureButton = $FireButton
var optionCardBluePrint: PackedScene = preload("res://Scenes/HUD/option_card.tscn")


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
