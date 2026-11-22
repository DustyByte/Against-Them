extends Control

## Pops up from the Home screen's profile notch: portrait (with a picker to
## change it), username, player ID and lifetime combat stats.
## Also shows other players' profiles (from a leaderboard), read-only, with the
## stats the server has counted for them.

const PICKER_OPTION_SIZE := Vector2(96, 96)

## Shown in order, three per row. "stat" is the AchievementManager stat (your
## own card), "server" the matching stat the server keeps (other players).
const STATS: Array[Dictionary] = [
	{"stat": "lifetime_kills", "server": "kills", "name": "ENEMIES SLAIN"},
	{"stat": "best_run_kills", "server": "bestRunKills", "name": "MOST KILLS IN A RUN"},
	{"stat": "best_wave_reached", "server": "bestWave", "name": "HIGHEST WAVE"},
	{"stat": "boss_kills", "server": "bossKills", "name": "BOSSES SLAIN"},
	{"stat": "runs_completed", "server": "runs", "name": "DESCENTS"},
	{"stat": "best_run_seconds", "server": "bestSeconds", "name": "LONGEST SURVIVAL", "time": true},
]

## Set before adding the card to show another player: {"id", "name", "avatar"}.
var other: Dictionary = {}

@onready var _caption: Label = $Center/Dialog/VBox/Caption
@onready var _dim: ColorRect = $Dim
@onready var _dialog: PanelContainer = $Center/Dialog
@onready var _avatar_holder: Control = $Center/Dialog/VBox/Identity/AvatarHolder
@onready var _avatar: AvatarPortrait = $Center/Dialog/VBox/Identity/AvatarHolder/Avatar
@onready var _edit_btn: Panel = $Center/Dialog/VBox/Identity/AvatarHolder/EditButton
@onready var _username: Label = $Center/Dialog/VBox/Identity/Info/Username
@onready var _player_id: Label = $Center/Dialog/VBox/Identity/Info/PlayerId
@onready var _claim_gap: Control = $Center/Dialog/VBox/Identity/Info/ClaimGap
@onready var _claim_btn: Panel = $Center/Dialog/VBox/Identity/Info/ClaimButton
@onready var _stats: GridContainer = $Center/Dialog/VBox/Stats
@onready var _close_btn: Panel = $Center/Dialog/VBox/CloseButton
@onready var _picker_blocker: ColorRect = $PickerBlocker
@onready var _picker: PanelContainer = $Picker
@onready var _picker_options: HBoxContainer = $Picker/VBox/Options

var _on_tap: Callable   # home.gd's tap handler: plays the menu sound, then runs the action
var _closing := false


func _ready() -> void:
	_on_tap = $"../.."._check_if_touch_then_execute
	_build_stats()
	_close_btn.gui_input.connect(_on_tap.bind(_close_btn, _close))
	_dim.gui_input.connect(_on_backdrop_input.bind(_dim, _close))

	if not other.is_empty():
		_show_other()
		_play_entrance()
		return

	_show_identity()
	PlayerProfile.changed.connect(_show_identity)   # e.g. the account finishes registering
	_fill_stats(func(entry: Dictionary) -> int: return AchievementManager.get_stat(entry.stat))
	_build_picker()

	_claim_btn.gui_input.connect(_on_tap.bind(_claim_btn, $"../..".open_account_setup))
	_edit_btn.gui_input.connect(_on_tap.bind(_edit_btn, _open_picker))
	_avatar.gui_input.connect(_on_tap.bind(_avatar, _open_picker))
	_picker_blocker.gui_input.connect(_on_backdrop_input.bind(_picker_blocker, _close_picker))
	_play_entrance()


func _show_identity() -> void:
	_username.text = PlayerProfile.username
	_player_id.text = tr("PLAYER ID") + "  ·  " + PlayerProfile.player_id
	_avatar.avatar = PlayerProfile.avatar
	_claim_btn.visible = not PlayerProfile.claimed
	_claim_gap.visible = _claim_btn.visible
	if _picker_options.get_child_count() > 0:
		_refresh_picker()


## Another player: what the leaderboard already knows shows at once, their
## stats once the server answers.
func _show_other() -> void:
	_caption.text = "PLAYER PROFILE"
	_username.text = str(other.get("name", ""))
	_player_id.text = tr("PLAYER ID") + "  ·  " + str(other.get("id", ""))
	_avatar.avatar = int(other.get("avatar", 0))
	_edit_btn.visible = false
	_claim_btn.visible = false
	_claim_gap.visible = false

	var profile: Dictionary = await Leaderboards.get_profile(str(other.get("id", "")))
	if not is_inside_tree():
		return   # closed while loading
	if profile.is_empty():
		for tile in _stats.get_children():
			tile.get_node("VBox/Value").text = "?"
		return
	_username.text = str(profile.get("username", _username.text))
	_avatar.avatar = int(profile.get("avatar", _avatar.avatar))
	var stats: Dictionary = profile.get("stats", {})
	_fill_stats(func(entry: Dictionary) -> int: return int(stats.get(entry.server, 0)))


## One tile per stat, values shown as "-" until filled in.
func _build_stats() -> void:
	var template: PanelContainer = _stats.get_node("Stat")
	for i in STATS.size():
		var tile: PanelContainer = template if i == 0 else template.duplicate()
		if i > 0:
			_stats.add_child(tile)
		tile.get_node("VBox/Value").text = "-"
		tile.get_node("VBox/Name").text = STATS[i].name


## `value_of` returns a stat's value given its STATS entry.
func _fill_stats(value_of: Callable) -> void:
	for i in STATS.size():
		var entry: Dictionary = STATS[i]
		var value: int = value_of.call(entry)
		_stats.get_child(i).get_node("VBox/Value").text = format_stat(value, entry.get("time", false))


static func format_stat(value: int, is_time: bool) -> String:
	return _format_time(value) if is_time else _format_count(value)


# --- Portrait picker ---------------------------------------------------------

func _build_picker() -> void:
	for i in PlayerProfile.AVATARS.size():
		var option := AvatarPortrait.new()
		option.custom_minimum_size = PICKER_OPTION_SIZE
		option.avatar = i
		option.mouse_filter = Control.MOUSE_FILTER_STOP
		_picker_options.add_child(option)
		option.gui_input.connect(_on_tap.bind(option, _on_avatar_picked.bind(i)))
	_refresh_picker()


func _refresh_picker() -> void:
	for option: AvatarPortrait in _picker_options.get_children():
		option.highlighted = option.avatar == PlayerProfile.avatar
		option.modulate.a = 1.0 if option.highlighted else 0.65


func _open_picker() -> void:
	_picker_blocker.visible = true
	_picker.visible = true
	_picker.reset_size()
	# Drop down from under the portrait, kept on screen.
	var at := _avatar_holder.global_position + Vector2(-8, _avatar_holder.size.y + 22)
	at.x = clampf(at.x, 16.0, size.x - _picker.size.x - 16.0)
	_picker.position = at
	_picker.pivot_offset = Vector2(40, 0)
	_picker.modulate.a = 0.0
	_picker.scale = Vector2(0.94, 0.94)
	var tween := create_tween().set_parallel()
	tween.tween_property(_picker, "modulate:a", 1.0, 0.14)
	tween.tween_property(_picker, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_picker() -> void:
	_picker.visible = false
	_picker_blocker.visible = false


func _on_avatar_picked(index: int) -> void:
	PlayerProfile.set_avatar(index)
	_avatar.avatar = index
	_refresh_picker()
	_close_picker()


# --- Closing -----------------------------------------------------------------

## Backdrops swallow every touch (so nothing behind reacts) and act on a tap.
func _on_backdrop_input(event: InputEvent, backdrop: Control, action: Callable) -> void:
	if event is InputEventScreenTouch:
		accept_event()
	_on_tap.call(event, backdrop, action)


func _close() -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.14)
	tween.tween_property(_dialog, "scale", Vector2(0.97, 0.97), 0.14)
	await tween.finished
	queue_free()


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


# --- Formatting --------------------------------------------------------------

static func _format_count(value: int) -> String:
	var digits := str(value)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out


static func _format_time(seconds: int) -> String:
	if seconds >= 3600:
		return "%d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
	return "%d:%02d" % [seconds / 60, seconds % 60]
