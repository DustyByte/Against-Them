extends Node

## Backs the player's progress up to their account on the server, and restores
## it when they sign in on a device.
##
## The save is the progress files themselves (Echoes, upgrades, inventory,
## achievements) bundled into one string; the server stores it without looking
## inside. Device settings and the profile file are not part of it.
##
## Only claimed accounts (with a username and password) are backed up: a guest
## can't sign in anywhere else, so its save could never be downloaded. Claiming
## uploads right away.
##
## Uploads are cheap on purpose:
##   - they happen a few seconds after progress changes (a finished run, a
##     purchase, a claim), so a burst of changes becomes one upload,
##   - plus right away when the app goes to the background,
##   - and never when nothing changed since the last upload (hash check).
## Nothing is downloaded on a normal launch; the device's copy is the current one.

const FILES: Array[String] = ["meta_progression.cfg", "upgrades.cfg", "inventory.cfg", "achievements.cfg"]
const STATE_PATH := "user://cloud_save.cfg"
const FORMAT := 1
const UPLOAD_DELAY := 4.0

var _last_hash := ""      # hash of the last save the server accepted
var _uploading := false
var _upload_again := false
var _timer: Timer


func _ready() -> void:
	var state := ConfigFile.new()
	if state.load(STATE_PATH) == OK:
		_last_hash = state.get_value("cloud_save", "last_hash", "")

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = UPLOAD_DELAY
	_timer.timeout.connect(upload_now)
	add_child(_timer)

	MetaProgression.echoes_changed.connect(_on_progress_changed.unbind(1))
	UpgradeManager.rank_changed.connect(_on_progress_changed.unbind(2))
	InventoryManager.anchor_shards_changed.connect(_on_progress_changed.unbind(1))
	InventoryManager.skins_changed.connect(_on_progress_changed)
	InventoryManager.equipped_skin_changed.connect(_on_progress_changed.unbind(1))
	AchievementManager.achievement_claimed.connect(_on_progress_changed.unbind(1))
	PlayerProfile.changed.connect(_on_progress_changed)   # e.g. a new account is ready
	_on_progress_changed()   # anything from last session that didn't make it up


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		upload_now()


func _on_progress_changed() -> void:
	_timer.start()   # restarts the wait, so several changes in a row upload once


## Uploads the current progress if it changed since the last upload.
func upload_now() -> void:
	_timer.stop()
	if not PlayerProfile.can_sync() or not PlayerProfile.claimed:
		return
	if _uploading:
		_upload_again = true
		return
	var save := collect()
	var save_hash := save.sha256_text()
	if save_hash == _last_hash:
		return

	_uploading = true
	var res: Dictionary = await PlayerProfile.api(HTTPClient.METHOD_PUT, "/players/me/save", {"save": save})
	_uploading = false
	if res.code == 204:
		_remember(save_hash)
	elif res.code == 401:
		PlayerProfile.handle_auth_failure(res)
	if _upload_again:
		_upload_again = false
		upload_now()


## The progress files bundled into one string.
func collect() -> String:
	AchievementManager.flush()   # stats are saved on a timer; get the latest onto disk
	var files := {}
	for file_name in FILES:
		var path := "user://" + file_name
		if FileAccess.file_exists(path):
			files[file_name] = FileAccess.get_file_as_string(path)
	return JSON.stringify({"format": FORMAT, "files": files})


## Replaces this device's progress with a save from the server. Returns false
## (and changes nothing) if the save can't be read.
func apply(save: String) -> bool:
	var parsed = JSON.parse_string(save)
	if not (parsed is Dictionary) or int(parsed.get("format", 0)) != FORMAT or not (parsed.get("files") is Dictionary):
		push_warning("Cloud save is in an unknown format; keeping this device's progress.")
		return false

	var files: Dictionary = parsed.files
	for file_name in FILES:
		var path := "user://" + file_name
		if files.has(file_name):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(str(files[file_name]))
			file.close()
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	MetaProgression.reload_from_disk()
	UpgradeManager.reload_from_disk()
	InventoryManager.reload_from_disk()
	AchievementManager.reload_from_disk()
	_timer.stop()
	_remember(collect().sha256_text())   # the server already has exactly this
	return true


## Forget what was last uploaded (the account changed), so the next upload goes through.
func forget() -> void:
	_remember("")


func _remember(save_hash: String) -> void:
	_last_hash = save_hash
	var state := ConfigFile.new()
	state.set_value("cloud_save", "last_hash", _last_hash)
	state.save(STATE_PATH)
