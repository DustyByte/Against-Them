class_name OptionCard
extends PanelContainer

signal selected

@onready var cardName: Label = $MarginContainer/VBoxContainer/Name
@onready var cardDescription: Label = $MarginContainer/VBoxContainer/MarginContainer/Description
@onready var selectButton: TouchScreenButton = $MarginContainer/TouchScreenButton
var optionDisplaying: Option = null


func setup_for_option(option: Option) -> void:
	optionDisplaying = option
	cardName.text = option.name
	cardDescription.text = option.description


func handle_selected_button_pressed() -> void:
	selected.emit(optionDisplaying)
