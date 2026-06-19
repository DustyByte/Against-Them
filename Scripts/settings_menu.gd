extends Control

signal returnPressed

@onready var ui_sfx_checkbox_touch_panel: Panel = $MarginContainer/VBoxContainer/MarginContainer1/UISFXCheckBox/Panel
@onready var ui_sfx_checkbox: CheckBox = $MarginContainer/VBoxContainer/MarginContainer1/UISFXCheckBox
@onready var game_world_sfx_checkbox_touch_panel: Panel = $MarginContainer/VBoxContainer/MarginContainer2/GameWorldSFXCheckBox/Panel
@onready var game_world_sfx_checkbox: CheckBox = $MarginContainer/VBoxContainer/MarginContainer2/GameWorldSFXCheckBox
@onready var return_button: Panel = $MarginContainer/VBoxContainer/MarginContainer3/ReturnButton
@onready var heptic_feedback_checkbox_panel: Panel = $MarginContainer/VBoxContainer/MarginContainer4/HepticFeedbackCheckBox/Panel
@onready var heptic_feedback_checkbox: CheckBox = $MarginContainer/VBoxContainer/MarginContainer4/HepticFeedbackCheckBox


func _ready() -> void:
	ui_sfx_checkbox.button_pressed = SettingsManager.settings.ui_sfx
	game_world_sfx_checkbox.button_pressed = SettingsManager.settings.game_world_sfx
	heptic_feedback_checkbox.button_pressed = SettingsManager.settings.is_heptic_feedback_enabled
	
	var _check_if_touch_then_execute: Callable = $"../.."._check_if_touch_then_execute
	ui_sfx_checkbox_touch_panel.gui_input.connect(_check_if_touch_then_execute.bind(_on_ui_sfx_toggled))
	game_world_sfx_checkbox_touch_panel.gui_input.connect(_check_if_touch_then_execute.bind(_on_game_world_sfx_toggled))
	heptic_feedback_checkbox_panel.gui_input.connect(_check_if_touch_then_execute.bind(_on_heptic_feedback_toggled))
	return_button.gui_input.connect(_check_if_touch_then_execute.bind(_on_return_pressed))


func _on_heptic_feedback_toggled() -> void:
	var enabled: bool = !heptic_feedback_checkbox.button_pressed
	heptic_feedback_checkbox.button_pressed = enabled
	
	global.IS_HEPTIC_FEEDBACK_PERMITTED = enabled
	SettingsManager.settings.is_heptic_feedback_enabled = enabled
	SettingsManager.save_settings()


func _on_ui_sfx_toggled() -> void:
	var enabled: bool = !ui_sfx_checkbox.button_pressed
	ui_sfx_checkbox.button_pressed = enabled
	
	global.SFX_TYPES_PERM["ui"] = enabled
	SettingsManager.settings.ui_sfx = enabled
	SettingsManager.save_settings()


func _on_game_world_sfx_toggled() -> void:
	var enabled: bool = !game_world_sfx_checkbox.button_pressed
	game_world_sfx_checkbox.button_pressed = enabled
	
	global.SFX_TYPES_PERM["game_world"] = enabled
	SettingsManager.settings.game_world_sfx = enabled
	SettingsManager.save_settings()


func _on_return_pressed() -> void:
	returnPressed.emit()
