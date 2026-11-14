extends Control

signal returnPressed

const COLUMN_PATH := "Center/Dialog/VBox/Columns/"
const KNOB_OFF_X := 4.0
const KNOB_ON_X := 38.0          # toggle width 68 - knob 26 - 4
const TOGGLE_TIME := 0.18

@onready var _ui_sfx_row: PanelContainer = get_node(COLUMN_PATH + "Left/UISFXRow")
@onready var _world_sfx_row: PanelContainer = get_node(COLUMN_PATH + "Left/WorldSFXRow")
@onready var _haptic_row: PanelContainer = get_node(COLUMN_PATH + "Left/HapticRow")
@onready var _languages: VBoxContainer = get_node(COLUMN_PATH + "Right/Scroll/List/Languages")
@onready var _account_avatar: AvatarPortrait = $Center/Dialog/VBox/Account/HBox/Avatar
@onready var _account_name: Label = $Center/Dialog/VBox/Account/HBox/Text/Name
@onready var _account_hint: Label = $Center/Dialog/VBox/Account/HBox/Text/Hint
@onready var _switch_btn: Panel = $Center/Dialog/VBox/Account/HBox/SwitchButton
@onready var _delete_btn: Panel = $Center/Dialog/VBox/Account/HBox/DeleteButton
@onready var _return_button: Panel = $Center/Dialog/VBox/ReturnButton
@onready var _dim: ColorRect = $Dim
@onready var _dialog: PanelContainer = $Center/Dialog

var _check_if_touch_then_execute: Callable
var _option_style: StyleBoxFlat
var _option_selected_style: StyleBoxFlat


func _ready() -> void:
	_check_if_touch_then_execute = $"../.."._check_if_touch_then_execute
	var s := SettingsManager.settings

	_setup_toggle(_ui_sfx_row, s.ui_sfx, func(on: bool):
		global.SFX_TYPES_PERM["ui"] = on
		s.ui_sfx = on)
	_setup_toggle(_world_sfx_row, s.game_world_sfx, func(on: bool):
		global.SFX_TYPES_PERM["game_world"] = on
		s.game_world_sfx = on)
	_setup_toggle(_haptic_row, s.is_heptic_feedback_enabled, func(on: bool):
		global.IS_HEPTIC_FEEDBACK_PERMITTED = on
		s.is_heptic_feedback_enabled = on)

	_build_language_list()
	_show_account()
	PlayerProfile.changed.connect(_show_account)
	var home := $"../.."
	_switch_btn.gui_input.connect(_check_if_touch_then_execute.bind(_switch_btn, home.open_switch_account))
	_delete_btn.gui_input.connect(_check_if_touch_then_execute.bind(_delete_btn, home.open_delete_account))
	_return_button.gui_input.connect(_check_if_touch_then_execute.bind(_return_button, func(): returnPressed.emit()))
	_play_entrance()


# --- Toggles -----------------------------------------------------------------

## The whole row is the touch target; the switch on the right shows the state.
func _setup_toggle(row: PanelContainer, value: bool, apply: Callable) -> void:
	row.set_meta("on", value)
	_show_toggle(row, value, false)
	row.gui_input.connect(_check_if_touch_then_execute.bind(row, func():
		var on: bool = not row.get_meta("on")
		row.set_meta("on", on)
		apply.call(on)
		SettingsManager.save_settings()
		_show_toggle(row, on, true)))


func _show_toggle(row: PanelContainer, on: bool, animate: bool) -> void:
	var toggle := row.get_node("HBox/Toggle")
	var knob: Panel = toggle.get_node("Knob")
	var fill: Panel = toggle.get_node("Fill")
	var name_label: Label = row.get_node("HBox/Text/Name")
	var knob_x := KNOB_ON_X if on else KNOB_OFF_X
	var fill_a := 1.0 if on else 0.0
	var knob_tint := Color.WHITE if on else Color(0.62, 0.68, 0.76)
	var name_tint := Color.WHITE if on else Color(0.7, 0.74, 0.8)
	if not animate:
		knob.position.x = knob_x
		fill.modulate.a = fill_a
		knob.self_modulate = knob_tint
		name_label.modulate = name_tint
		return
	var tween := create_tween().set_parallel()
	tween.tween_property(knob, "position:x", knob_x, TOGGLE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(fill, "modulate:a", fill_a, TOGGLE_TIME)
	tween.tween_property(knob, "self_modulate", knob_tint, TOGGLE_TIME)
	tween.tween_property(name_label, "modulate", name_tint, TOGGLE_TIME)


# --- Language ----------------------------------------------------------------

## One option per entry in SettingsManager.LANGUAGES; the scene holds the first
## one as the template.
func _build_language_list() -> void:
	var template: PanelContainer = _languages.get_node("Option")
	_option_style = template.get_theme_stylebox("panel")
	_option_selected_style = _option_style.duplicate()
	_option_selected_style.bg_color = Color(0.62, 0.88, 0.95, 0.1)
	_option_selected_style.border_color = Color(0.62, 0.88, 0.95, 0.7)

	for i in SettingsManager.LANGUAGES.size():
		var lang: Dictionary = SettingsManager.LANGUAGES[i]
		var option: PanelContainer = template if i == 0 else template.duplicate()
		if i > 0:
			_languages.add_child(option)
		option.set_meta("code", lang.code)
		option.get_node("HBox/Text/Native").text = lang.native
		var english: Label = option.get_node("HBox/Text/English")
		english.text = lang.english
		english.visible = lang.native != lang.english
		option.gui_input.connect(_check_if_touch_then_execute.bind(option, _on_language_picked.bind(lang.code)))
	_refresh_language_list()


func _on_language_picked(code: String) -> void:
	if code == SettingsManager.settings.language:
		return
	SettingsManager.set_language(code)
	_refresh_language_list()


func _refresh_language_list() -> void:
	for option in _languages.get_children():
		var picked: bool = option.get_meta("code") == SettingsManager.settings.language
		option.add_theme_stylebox_override("panel", _option_selected_style if picked else _option_style)
		option.get_node("HBox/Radio/Dot").visible = picked
		option.get_node("HBox/Radio").modulate.a = 1.0 if picked else 0.45
		option.get_node("HBox/Status").visible = picked


# --- Account -----------------------------------------------------------------

func _show_account() -> void:
	_account_avatar.avatar = PlayerProfile.avatar
	_account_name.text = PlayerProfile.username
	var status := "" if PlayerProfile.claimed else "   ·   GUEST"
	if PlayerProfile.signed_out:
		status = "   ·   SIGNED OUT"
	_account_hint.text = "ID  " + PlayerProfile.player_id + status


# --- Entrance ----------------------------------------------------------------

func _play_entrance() -> void:
	_dim.modulate.a = 0.0
	_dialog.modulate.a = 0.0
	await get_tree().process_frame   # let the panel lay out first
	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 1.0, 0.2)
	tween.tween_property(_dialog, "modulate:a", 1.0, 0.18)
	tween.tween_property(_dialog, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
