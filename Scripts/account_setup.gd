extends Control

## The account dialog. Set `mode` before adding it to the tree:
##   CLAIM  - pick a unique username + password (after the first descend, or
##            from the profile card until claimed)
##   LOGIN  - sign in to a claimed account (Settings > Switch Account)
##   DELETE - type DELETE to delete the account (Settings > Delete Account)

signal finished

enum Mode { CLAIM, LOGIN, DELETE }

const KEYBOARD_GAP := 20.0      # space kept between the focused field and the keyboard
const FOLLOW_SPEED := 14.0
const DELETE_WORD := "DELETE"
const DANGER := Color(1, 0.5, 0.45)

var mode: Mode = Mode.CLAIM

@onready var _dim: ColorRect = $Dim
@onready var _dialog: PanelContainer = $Dialog
@onready var _caption: Label = $Dialog/VBox/Caption
@onready var _title: Label = $Dialog/VBox/Title
@onready var _hint: Label = $Dialog/VBox/Hint
@onready var _form: VBoxContainer = $Dialog/VBox/Form
@onready var _username_label: Label = $Dialog/VBox/Form/UsernameLabel
@onready var _username: LineEdit = $Dialog/VBox/Form/Username
@onready var _username_error: Label = $Dialog/VBox/Form/UsernameError
@onready var _password: LineEdit = $Dialog/VBox/Form/PasswordRow/Password
@onready var _password_error: Label = $Dialog/VBox/Form/PasswordError
@onready var _show_btn: Panel = $Dialog/VBox/Form/PasswordRow/Show
@onready var _status: Label = $Dialog/VBox/Status
@onready var _buttons: HBoxContainer = $Dialog/VBox/Buttons
@onready var _later_btn: Panel = $Dialog/VBox/Buttons/Later
@onready var _confirm_btn: Panel = $Dialog/VBox/Buttons/Confirm
@onready var _confirm_label: Label = $Dialog/VBox/Buttons/Confirm/Label

var _on_tap: Callable
var _confirm_text := "CONFIRM"
var _busy := false
var _closing := false


func _ready() -> void:
	_on_tap = $"../.."._check_if_touch_then_execute
	match mode:
		Mode.CLAIM: _setup_claim()
		Mode.LOGIN: _setup_login()
		Mode.DELETE: _setup_delete()
	_confirm_label.text = _confirm_text

	_later_btn.gui_input.connect(_on_tap.bind(_later_btn, _close))
	_confirm_btn.gui_input.connect(_on_tap.bind(_confirm_btn, _submit))
	_show_btn.gui_input.connect(_on_tap.bind(_show_btn, _toggle_show_password))
	_dim.gui_input.connect(_on_dim_input)
	_username.text_changed.connect(_on_username_changed)
	_password.text_changed.connect(func(_t): _clear_error(_password_error))
	_username.text_submitted.connect(func(_t): _submit() if mode == Mode.DELETE else _password.grab_focus())
	_password.text_submitted.connect(func(_t): _submit())
	_play_entrance()


func _setup_claim() -> void:
	if PlayerProfile.account_prompt_shown or AchievementManager.get_stat("runs_completed") == 0:
		_hint.text = "Pick a unique username and a password to make this account yours."


func _setup_login() -> void:
	_caption.text = "SWITCH ACCOUNT"
	_title.text = "SIGN IN"
	_hint.text = "Sign in with the username and password of a claimed account. Its saved progress replaces the progress on this device."
	if PlayerProfile.signed_out:
		_hint.text = "This account was signed in on another device. Sign in again to keep playing on this one; its saved progress replaces the progress here."
	elif PlayerProfile.is_registered() and not PlayerProfile.claimed:
		_hint.text += " This account has no username yet, so you won't be able to come back to it."
	_username.placeholder_text = "Your username"
	_username.max_length = 32
	_password.placeholder_text = "Your password"
	_later_btn.get_node("Label").text = "CANCEL"
	_confirm_text = "SIGN IN"


func _setup_delete() -> void:
	_caption.text = "ACCOUNT"
	_caption.add_theme_color_override("font_color", Color(DANGER, 0.85))
	_title.text = "DELETE ACCOUNT"
	_hint.text = "This permanently deletes %s (ID %s) and erases all progress on this device: Echoes, upgrades, skins and achievements. It can't be undone." \
		% [PlayerProfile.username, PlayerProfile.player_id]
	_username_label.text = 'TYPE "%s" TO CONFIRM' % DELETE_WORD
	_username_label.add_theme_color_override("font_color", Color(DANGER, 0.85))
	_username.placeholder_text = DELETE_WORD
	_username.max_length = 12
	for node_name in ["PasswordLabel", "PasswordGap", "PasswordRow", "PasswordError"]:
		_form.get_node(node_name).visible = false
	_later_btn.get_node("Label").text = "CANCEL"
	_confirm_text = "DELETE"
	var danger_style := StyleBoxFlat.new()
	danger_style.bg_color = Color(0.85, 0.28, 0.25)
	danger_style.set_corner_radius_all(8)
	_confirm_btn.add_theme_stylebox_override("panel", danger_style)
	_confirm_label.add_theme_color_override("font_color", Color.WHITE)
	_refresh_delete_ready()


## Keeps the dialog centred, or lifts it so the focused field sits just above
## the on-screen keyboard.
func _process(delta: float) -> void:
	var screen := get_viewport_rect().size
	var target := (screen - _dialog.size) * 0.5
	var keyboard := _keyboard_height()
	var focused := get_viewport().gui_get_focus_owner()
	if keyboard > 0.0 and focused is LineEdit:
		var field_bottom: float = focused.global_position.y - _dialog.position.y + focused.size.y
		target.y = minf(target.y, screen.y - keyboard - KEYBOARD_GAP - field_bottom)
	_dialog.position = _dialog.position.lerp(target, minf(1.0, delta * FOLLOW_SPEED))


## The virtual keyboard's height in this viewport's units (0 when hidden).
func _keyboard_height() -> float:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return 0.0
	var pixels := DisplayServer.virtual_keyboard_get_height()
	if pixels <= 0:
		return 0.0
	return pixels * get_viewport_rect().size.y / float(DisplayServer.window_get_size().y)


# --- Submitting --------------------------------------------------------------

func _submit() -> void:
	if _busy:
		return
	_status.text = ""
	match mode:
		Mode.CLAIM: await _submit_claim()
		Mode.LOGIN: await _submit_login()
		Mode.DELETE: await _submit_delete()


func _submit_claim() -> void:
	var username := _username.text.strip_edges()
	var password := _password.text
	var name_problem := PlayerProfile.check_username(username)
	var password_problem := PlayerProfile.check_password(password)
	_show_error(_username_error, name_problem)
	_show_error(_password_error, password_problem)
	if name_problem != "" or password_problem != "":
		return

	_set_busy(true)
	var result: Dictionary = await PlayerProfile.claim_account(username, password)
	if not is_inside_tree():
		return
	_set_busy(false)
	if result.ok:
		_show_done("WELCOME, " + PlayerProfile.username.to_upper(), "Your username is locked in. Remember your password.")
		return
	match result.field:
		"username": _show_error(_username_error, result.error)
		"password": _show_error(_password_error, result.error)
		_: _status.text = result.error


func _submit_login() -> void:
	var username := _username.text.strip_edges()
	var password := _password.text
	_show_error(_username_error, "Enter your username." if username == "" else "")
	_show_error(_password_error, "Enter your password." if password == "" else "")
	if username == "" or password == "":
		return

	_set_busy(true)
	var result: Dictionary = await PlayerProfile.log_in(username, password)
	if not is_inside_tree():
		return
	_set_busy(false)
	if not result.ok:
		_status.text = result.error
		return
	if not result.restored:
		_show_done("WELCOME BACK, " + PlayerProfile.username.to_upper(), "You're signed in. This device's progress is now saved to your account.")
		return
	# The account's progress replaced this device's: reload the home screen with it.
	_show_done("WELCOME BACK, " + PlayerProfile.username.to_upper(), "Your saved progress is loaded.", false)
	await get_tree().create_timer(1.6).timeout
	get_tree().reload_current_scene()


func _submit_delete() -> void:
	if not _delete_word_typed():
		_show_error(_username_error, 'Type "%s" to confirm.' % DELETE_WORD)
		return

	_set_busy(true)
	var result: Dictionary = await PlayerProfile.delete_account()
	if not is_inside_tree():
		return
	_set_busy(false)
	if not result.ok:
		_status.text = result.error
		return
	_show_done("ACCOUNT DELETED", "Starting fresh.", false)
	# Everything was erased: reload the home screen as a brand-new player.
	await get_tree().create_timer(1.6).timeout
	get_tree().reload_current_scene()


func _delete_word_typed() -> bool:
	return _username.text.strip_edges().to_upper() == DELETE_WORD


func _refresh_delete_ready() -> void:
	_confirm_btn.modulate.a = 1.0 if _delete_word_typed() else 0.4


# --- Helpers -----------------------------------------------------------------

func _on_username_changed(_text: String) -> void:
	_clear_error(_username_error)
	if mode == Mode.DELETE:
		_refresh_delete_ready()


func _set_busy(busy: bool) -> void:
	_busy = busy
	_username.editable = not busy
	_password.editable = not busy
	_confirm_btn.modulate.a = 0.55 if busy else 1.0
	_confirm_label.text = "PLEASE WAIT..." if busy else _confirm_text
	if busy:
		get_viewport().gui_release_focus()   # drop the keyboard
	elif mode == Mode.DELETE:
		_refresh_delete_ready()


## Swaps the form for a short message, then closes (unless the caller takes over).
func _show_done(title: String, message: String, close_after: bool = true) -> void:
	_title.text = title
	_hint.text = message
	_form.visible = false
	_status.visible = false
	$Dialog/VBox/ButtonsGap.visible = false
	_buttons.visible = false
	_dialog.reset_size()   # shrink to the message; _process re-centres it
	if not close_after:
		return   # the caller takes over (reloads the scene)
	await get_tree().create_timer(1.6).timeout
	_close()


func _toggle_show_password() -> void:
	_password.secret = not _password.secret
	_show_btn.get_node("Label").text = "SHOW" if _password.secret else "HIDE"


func _show_error(label: Label, text: String) -> void:
	label.text = text
	if text != "":
		label.modulate.a = 0.0
		create_tween().tween_property(label, "modulate:a", 1.0, 0.15)


func _clear_error(label: Label) -> void:
	label.text = ""
	_status.text = ""


## Tapping outside the dialog just hides the keyboard; it never discards input.
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		accept_event()
		if event.pressed:
			get_viewport().gui_release_focus()


func _close() -> void:
	if _closing or _busy:
		return
	_closing = true
	set_process(false)
	get_viewport().gui_release_focus()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	await tween.finished
	finished.emit()
	queue_free()


func _play_entrance() -> void:
	_dim.modulate.a = 0.0
	_dialog.modulate.a = 0.0
	await get_tree().process_frame   # let the dialog lay out first
	_dialog.position = (get_viewport_rect().size - _dialog.size) * 0.5
	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 1.0, 0.25)
	tween.tween_property(_dialog, "modulate:a", 1.0, 0.2)
	tween.tween_property(_dialog, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
