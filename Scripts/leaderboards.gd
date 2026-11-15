extends Node

## Talks to the server about runs and leaderboards.
## Registered as the "Leaderboards" autoload (after PlayerProfile).
##
## After each descend the run's numbers are sent once if the account can reach
## the server; offline runs aren't kept for later. The server checks the run is
## possible before it counts toward the account's stats and the leaderboards.
##
## Boards and other players' profiles are kept for a short while, so flipping
## between screens doesn't ask the server again.

## Board name on the server -> how it's shown.
const BOARDS: Array[Dictionary] = [
	{"id": "kills", "title": "ENEMIES SLAIN"},
	{"id": "wave", "title": "HIGHEST WAVE"},
	{"id": "time", "title": "LONGEST SURVIVAL", "time": true},
]

const BOARDS_MAX_AGE_MSEC := 30_000
const PROFILE_MAX_AGE_MSEC := 60_000
const PROFILE_CACHE_LIMIT := 50

var _boards: Dictionary = {}       # board id -> Array of {id, name, avatar, value}
var _boards_at: int = -BOARDS_MAX_AGE_MSEC
var _boards_request_running := false
var _profiles: Dictionary = {}     # player id -> {"data": Dictionary, "at": msec}

signal _boards_finished


## Sends a finished run: {"seconds", "wave", "kills", "bossKills"}.
func submit_run(run: Dictionary) -> void:
	if not PlayerProfile.can_sync():
		return
	var res: Dictionary = await PlayerProfile.api(HTTPClient.METHOD_POST, "/players/me/runs", run)
	if res.code == 200:
		_boards_at = -BOARDS_MAX_AGE_MSEC     # the boards may have changed
		_profiles.erase(PlayerProfile.player_id)
	elif res.code == 401:
		PlayerProfile.handle_auth_failure(res)
	elif res.code == 422:
		push_warning("The server rejected this run: %s" % run)


## All three boards: {"kills": [...], "wave": [...], "time": [...]}, best
## first, each entry {"id", "name", "avatar", "value"}. Empty if unreachable.
func get_boards() -> Dictionary:
	if _boards_request_running:
		await _boards_finished
		return _boards
	if Time.get_ticks_msec() - _boards_at < BOARDS_MAX_AGE_MSEC and not _boards.is_empty():
		return _boards

	_boards_request_running = true
	var res: Dictionary = await PlayerProfile.api(HTTPClient.METHOD_GET, "/leaderboards")
	if res.code == 200:
		_boards = res.data
		_boards_at = Time.get_ticks_msec()
	_boards_request_running = false
	_boards_finished.emit()
	return _boards if res.code == 200 else {}


## Another player's public profile: {"playerId", "username", "avatar",
## "claimed", "stats": {...}}. Empty if it couldn't be loaded.
func get_profile(id: String) -> Dictionary:
	var cached: Dictionary = _profiles.get(id, {})
	if not cached.is_empty() and Time.get_ticks_msec() - int(cached.at) < PROFILE_MAX_AGE_MSEC:
		return cached.data

	var res: Dictionary = await PlayerProfile.api(HTTPClient.METHOD_GET, "/players/" + id.uri_encode())
	if res.code != 200:
		return {}
	if _profiles.size() >= PROFILE_CACHE_LIMIT:
		_profiles.clear()
	_profiles[id] = {"data": res.data, "at": Time.get_ticks_msec()}
	return res.data
