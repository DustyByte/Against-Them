extends Node

## The player's public identity: name, ID and chosen portrait.
##
## On first launch the server creates a guest account and hands back a unique
## player ID, a generated unique username and a secret token, which are saved
## here. After that the game only talks to the server when something changes
## (no request at all on a normal launch), and the player can claim their own
## unique username and password. Offline changes are sent when the server is
## reachable again.

signal changed
signal _register_finished

const API_URL := "https://against-them-server.onrender.com"
const SAVE_PATH := "user://profile.cfg"
const SECTION := "profile"
## Render's free tier can take most of a minute to wake up.
const REQUEST_TIMEOUT := 70.0

## Built-in portraits the player can choose from. Placeholders ("?") for now;
## give each entry a "texture" once the art exists.
const AVATARS: Array[Dictionary] = [
	{"tint": Color(0.62, 0.88, 0.95)},   # cyan
	{"tint": Color(0.98, 0.74, 0.38)},   # amber
	{"tint": Color(0.76, 0.6, 0.98)},    # violet
]

## Shown until the server has created the account.
const PLACEHOLDER_USERNAME := "Guest"
const PLACEHOLDER_PLAYER_ID := "--------"

## Same rules the server enforces, checked here first to save a round trip.
const USERNAME_MIN := 3
const USERNAME_MAX := 16
const PASSWORD_MIN := 8
const PASSWORD_MAX := 64

var username: String = PLACEHOLDER_USERNAME
var player_id: String = PLACEHOLDER_PLAYER_ID
var avatar: int = 0
## True once the player has picked their own username and password.
var claimed: bool = false
## The "secure your account" popup has been shown (after the first descend).
var account_prompt_shown: bool = false
## The account was signed in on another device, which signed this one out.
## Nothing is sent to the server until the player signs in again.
var signed_out: bool = false

var _token: String = ""
var _avatar_unsynced := false   # changed offline; send it when we can
var _api_url := API_URL
var _registering := false
var _last_register_code := 0   # HTTP status of the last registration attempt (0 = no connection)


func _ready() -> void:
	# For local server testing: run the game with `-- --server=http://localhost:3000`.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			_api_url = arg.trim_prefix("--server=")
	_load()
	_sync()


func is_registered() -> bool:
	return _token != ""


## True when this device may talk to the server for this account.
func can_sync() -> bool:
	return is_registered() and not signed_out


## Sends a request as the current account (used by CloudSave).
func api(method: HTTPClient.Method, path: String, body: Dictionary = {}) -> Dictionary:
	return await _request(method, path, body)


## The server refused this device's token. Either the account is gone (deleted
## elsewhere): carry on as a new guest, keeping the progress on this device. Or
## it was signed in on another device: stop syncing until signed in again.
func handle_auth_failure(res: Dictionary) -> void:
	if str(res.data.get("reason", "")) == "gone":
		_forget_account()
		_sync()
	elif not signed_out:
		signed_out = true
		_save()
		changed.emit()


func _forget_account() -> void:
	_token = ""
	username = PLACEHOLDER_USERNAME
	player_id = PLACEHOLDER_PLAYER_ID
	claimed = false
	signed_out = false
	_avatar_unsynced = false
	CloudSave.forget()
	_save()
	changed.emit()


## The popup asking for a username and password should show now: after the
## first finished descend, once, until the account is claimed.
func should_prompt_account() -> bool:
	return not claimed and not account_prompt_shown and AchievementManager.get_stat("runs_completed") >= 1


func mark_account_prompt_shown() -> void:
	account_prompt_shown = true
	_save()


## Returns "" if the username is fine, otherwise what's wrong with it.
static func check_username(value: String) -> String:
	if value.length() < USERNAME_MIN or value.length() > USERNAME_MAX:
		return "Use %d to %d characters." % [USERNAME_MIN, USERNAME_MAX]
	var rule := RegEx.create_from_string("^[A-Za-z][A-Za-z0-9_]*$")
	if rule.search(value) == null:
		return "Letters, numbers and _ only, starting with a letter."
	return ""


static func check_password(password: String) -> String:
	if password.length() < PASSWORD_MIN:
		return "Use at least %d characters." % PASSWORD_MIN
	if password.length() > PASSWORD_MAX:
		return "Use at most %d characters." % PASSWORD_MAX
	return ""


## Claims a unique username and sets the password.
## Returns {"ok": bool, "error": String, "field": "username" | "password" | ""}.
func claim_account(new_username: String, password: String) -> Dictionary:
	if signed_out:
		return {"ok": false, "error": SIGNED_OUT_MESSAGE, "field": ""}
	if not is_registered():
		await _sync()
		if not is_registered():
			return {"ok": false, "error": _failure_message(_last_register_code), "field": ""}
	var res := await _request(HTTPClient.METHOD_POST, "/players/me/account",
		{"username": new_username, "password": password})
	if res.code == 200:
		claimed = true
		_apply(res.data, false)
		CloudSave.upload_now()   # from now on this account's progress is backed up
		return {"ok": true, "error": "", "field": ""}
	if res.data.has("field"):   # a problem with what was typed, e.g. the name is taken
		return {"ok": false, "error": str(res.data.error), "field": str(res.data.field)}
	if res.code == 401:
		handle_auth_failure(res)
	return {"ok": false, "error": _failure_message(res.code), "field": ""}


const SIGNED_OUT_MESSAGE := "This account was signed in on another device. Sign in again from Settings."


## What to tell the player when a request fails for reasons that aren't theirs.
static func _failure_message(code: int) -> String:
	if code == 0:
		return "Couldn't connect. Check your internet and try again."
	return "Our servers are having trouble right now. Please try again a little later."


## Signs in to a claimed account on this device.
## Returns {"ok": bool, "error": String, "restored": bool}; "restored" means the
## account's cloud save replaced this device's progress.
##
## An unclaimed guest account can't be reached again once you switch away, so
## it's deleted on the server. If the account has no cloud save yet, this
## device's progress becomes its progress.
func log_in(login_username: String, password: String) -> Dictionary:
	var res := await _request(HTTPClient.METHOD_POST, "/players/login",
		{"username": login_username, "password": password})
	if res.code != 200:
		var known: bool = res.code in [400, 401, 429] and res.data.has("error")
		return {"ok": false, "error": str(res.data.error) if known else _failure_message(res.code), "restored": false}

	var abandoned_guest := ""
	if is_registered() and not claimed and str(res.data.playerId) != player_id:
		abandoned_guest = "%s.%s" % [player_id, _token]
	_token = res.data.token
	_avatar_unsynced = false
	account_prompt_shown = true
	signed_out = false
	_apply(res.data, true)
	if abandoned_guest != "":
		_request(HTTPClient.METHOD_DELETE, "/players/me", {}, abandoned_guest)   # best effort

	CloudSave.forget()
	var restored := false
	if res.data.get("save") is String:
		restored = CloudSave.apply(res.data.save)
	if not restored:
		CloudSave.upload_now()   # this device's progress becomes the account's
	return {"ok": true, "error": "", "restored": restored}


## Deletes the account on the server (freeing its ID and username) and erases
## all progress on this device, then starts over as a fresh guest.
## Returns {"ok": bool, "error": String}.
func delete_account() -> Dictionary:
	if signed_out:
		return {"ok": false, "error": SIGNED_OUT_MESSAGE}
	if is_registered():
		var res := await _request(HTTPClient.METHOD_DELETE, "/players/me")
		var already_gone: bool = res.code == 401 and str(res.data.get("reason", "")) == "gone"
		if res.code == 401 and not already_gone:
			handle_auth_failure(res)
			return {"ok": false, "error": SIGNED_OUT_MESSAGE}
		if res.code != 204 and not already_gone:
			return {"ok": false, "error": _failure_message(res.code)}

	MetaProgression.reset_progress()
	UpgradeManager.reset_progress()
	InventoryManager.reset_progress()
	AchievementManager.reset_progress()

	_token = ""
	username = PLACEHOLDER_USERNAME
	player_id = PLACEHOLDER_PLAYER_ID
	avatar = 0
	claimed = false
	account_prompt_shown = false
	signed_out = false
	_avatar_unsynced = false
	CloudSave.forget()
	_save()
	changed.emit()
	_sync()   # get a new guest account
	return {"ok": true, "error": ""}


func set_avatar(index: int) -> void:
	index = clampi(index, 0, AVATARS.size() - 1)
	if index == avatar:
		return
	avatar = index
	_avatar_unsynced = true
	_save()
	changed.emit()
	if can_sync():
		_push_avatar()


# --- Server ------------------------------------------------------------------

## Creates the guest account if there isn't one yet and sends any change made
## offline. A normal launch with nothing pending makes no request at all.
func _sync() -> void:
	if signed_out:
		return
	if not is_registered():
		await _register()
	if _avatar_unsynced and is_registered():
		_push_avatar()


func _register() -> void:
	if _registering:   # already on its way (e.g. launch sync + a claim at once)
		await _register_finished
		return
	_registering = true
	var res := await _request(HTTPClient.METHOD_POST, "/players")
	_last_register_code = res.code
	if res.code == 201:
		_token = res.data.token
		_apply(res.data, false)   # keep a portrait picked before the account existed
		_avatar_unsynced = avatar != int(res.data.avatar)
	_registering = false
	_register_finished.emit()


func _push_avatar() -> void:
	var sent := avatar
	var res := await _request(HTTPClient.METHOD_PATCH, "/players/me", {"avatar": sent})
	if res.code == 200 and avatar == sent:
		_avatar_unsynced = false
		_save()
	elif res.code == 401:
		handle_auth_failure(res)


func _apply(data: Dictionary, take_avatar: bool) -> void:
	player_id = str(data.playerId)
	username = str(data.username)
	claimed = bool(data.get("claimed", claimed))
	if take_avatar:
		avatar = clampi(int(data.avatar), 0, AVATARS.size() - 1)
	_save()
	changed.emit()


## Returns {"code": HTTP status (0 if unreachable), "data": parsed JSON or {}}.
## `auth` overrides the credentials sent ("<playerId>.<token>"); by default the
## current account's are used.
func _request(method: HTTPClient.Method, path: String, body: Dictionary = {}, auth: String = "") -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if auth == "" and is_registered():
		auth = "%s.%s" % [player_id, _token]
	if auth != "":
		headers.append("Authorization: Bearer " + auth)
	var payload := JSON.stringify(body) if method not in [HTTPClient.METHOD_GET, HTTPClient.METHOD_DELETE] else ""
	var out := {"code": 0, "data": {}}
	if http.request(_api_url + path, headers, method, payload) == OK:
		var result: Array = await http.request_completed
		if result[0] == HTTPRequest.RESULT_SUCCESS:
			out.code = result[1]
			var text := (result[3] as PackedByteArray).get_string_from_utf8()
			var parsed = JSON.parse_string(text) if text != "" else null   # 204 has no body
			if parsed is Dictionary:
				out.data = parsed
	if out.code == 0 or out.code >= 500:
		push_warning("Profile server request failed: %s %s -> %s" % [method, path, out.code])
	http.queue_free()
	return out


# --- Save file ---------------------------------------------------------------

func _load() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	_token = file.get_value(SECTION, "token", "")
	avatar = clampi(int(file.get_value(SECTION, "avatar", 0)), 0, AVATARS.size() - 1)
	_avatar_unsynced = file.get_value(SECTION, "avatar_unsynced", false)
	claimed = file.get_value(SECTION, "claimed", false)
	account_prompt_shown = file.get_value(SECTION, "account_prompt_shown", false)
	signed_out = file.get_value(SECTION, "signed_out", false)
	if is_registered():
		username = file.get_value(SECTION, "username", PLACEHOLDER_USERNAME)
		player_id = file.get_value(SECTION, "player_id", PLACEHOLDER_PLAYER_ID)


func _save() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "token", _token)
	file.set_value(SECTION, "username", username)
	file.set_value(SECTION, "player_id", player_id)
	file.set_value(SECTION, "avatar", avatar)
	file.set_value(SECTION, "avatar_unsynced", _avatar_unsynced)
	file.set_value(SECTION, "claimed", claimed)
	file.set_value(SECTION, "account_prompt_shown", account_prompt_shown)
	file.set_value(SECTION, "signed_out", signed_out)
	file.save(SAVE_PATH)
