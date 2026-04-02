extends Control


signal optionChosen

@onready var cardBox: HBoxContainer = $HBoxContainer
@onready var expBar: ProgressBar = $ProgressBar
@onready var fireButton: TextureButton = $FireButton
var optionCardBluePrint: PackedScene = preload("res://Scenes/HUD/option_card.tscn")


func show_options(options: Array[Option]) -> void:
	for option in options:
		var card: OptionCard = optionCardBluePrint.instantiate()
		
		cardBox.add_child(card)
		card.setup_for_option(option)
		card.selected.connect(send_selection_signal)


func send_selection_signal(option: Option) -> void:
	optionChosen.emit(option)
	
	for child in cardBox.get_children():
		child.queue_free()
	
	get_tree().paused = false


func _ready() -> void:
	global.ON_RUN_HUD = self
