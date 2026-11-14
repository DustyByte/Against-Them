extends Control
## Shown on Home when the server reports a newer game version. A minor/patch
## update can be skipped ("Later"); a major/minor bump must be installed.

var setAsMustUpdate: bool = true
var latestVersion: String = ""

@onready var _dim: ColorRect = $DimBackground
@onready var _dialog: PanelContainer = $Center/Dialog
@onready var _title: Label = $Center/Dialog/VBox/Title
@onready var _message: Label = $Center/Dialog/VBox/Message
@onready var _installed: Label = $Center/Dialog/VBox/Versions/Row/Installed/Value
@onready var _latest: Label = $Center/Dialog/VBox/Versions/Row/Latest/Value
@onready var _maybe_later_btn: Panel = $Center/Dialog/VBox/Buttons/MaybeLaterButton
@onready var _update_btn: Panel = $Center/Dialog/VBox/Buttons/UpdateButton

func _ready() -> void:
	_installed.text = "v" + global.GAME_VERSION
	_latest.text = ("v" + latestVersion) if latestVersion != "" else "-"
	_update_btn.gui_input.connect(_check_if_touch.bind(_update_btn, _on_update_pressed))
	if setAsMustUpdate:
		_title.text = "UPDATE REQUIRED"
		_message.text = "This version is no longer supported.\nUpdate from the Play Store to keep playing."
		_maybe_later_btn.visible = false
	else:
		_message.text = "A new version of Against Them is on the Play Store."
		_maybe_later_btn.gui_input.connect(_check_if_touch.bind(_maybe_later_btn, _on_maybe_later_pressed))
	_play_entrance()

func _play_entrance() -> void:
	_dim.modulate.a = 0.0
	_dialog.modulate.a = 0.0
	await get_tree().process_frame   # let the panel lay out first
	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog.scale = Vector2(0.94, 0.94)
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 1.0, 0.3)
	tween.tween_property(_dialog, "modulate:a", 1.0, 0.25).set_delay(0.06)
	tween.tween_property(_dialog, "scale", Vector2.ONE, 0.35).set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _check_if_touch(event: InputEvent, control: Control, funcToCall: Callable) -> void:
	if Tap.is_tap(control, event):
		funcToCall.call()

## Opens the game's Play Store page (the store app if possible, else the
## browser), then quits so the player can install the update.
func _on_update_pressed() -> void:
	var id := "com.against_them"
	if OS.shell_open("market://details?id=" + id) != OK:
		OS.shell_open("https://play.google.com/store/apps/details?id=" + id)
	get_tree().quit()

func _on_maybe_later_pressed() -> void:
	get_tree().paused = false
	queue_free()
