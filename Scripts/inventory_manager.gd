extends Node
## What the player owns from the Shop: Anchor Shards (plus the daily limit on
## earning them through rewarded ads) and purchased skins. Saved to user://.

signal anchor_shards_changed(total: int)
signal daily_ads_changed(used: int, limit: int)
signal skins_changed
signal equipped_skin_changed(skin_id: String)

const SAVE_PATH: String = "user://inventory.cfg"
const SAVE_SECTION: String = "inventory"
const SAVE_VERSION: int = 1

## Rewarded ads that can be watched for Anchor Shards per day. The count
## resets at the phone's local midnight.
const DAILY_AD_LIMIT: int = 10

var anchor_shards: int = 0
var _ads_watched_today: int = 0
var _ads_date: String = ""   # local date ("YYYY-MM-DD") the counter belongs to
var _owned_skins: Array[String] = []
var equipped_skin: String = "default"


func _ready() -> void:
	_load()


# --- Anchor Shards ------------------------------------------------------------

func add_anchor_shards(amount: int) -> void:
	if amount <= 0:
		return
	anchor_shards += amount
	_save()
	anchor_shards_changed.emit(anchor_shards)


## Uses one shard. Returns false if the player has none.
func use_anchor_shard() -> bool:
	if anchor_shards <= 0:
		return false
	anchor_shards -= 1
	_save()
	anchor_shards_changed.emit(anchor_shards)
	return true


# --- Skins --------------------------------------------------------------------

func owns_skin(skin_id: String) -> bool:
	return skin_id == "default" or skin_id in _owned_skins


## Owned skins in purchase order, not counting the default.
func owned_skins() -> Array[String]:
	return _owned_skins.duplicate()


func equip_skin(skin_id: String) -> void:
	if not owns_skin(skin_id) or skin_id == equipped_skin:
		return
	equipped_skin = skin_id
	_save()
	equipped_skin_changed.emit(skin_id)


# --- Items --------------------------------------------------------------------

## How many of an item (see item_data.gd) the player has.
func get_item_amount(item_id: String) -> int:
	match item_id:
		"anchor_shard":
			return anchor_shards
	return 0


## Spends Echoes and unlocks the skin. Returns false if already owned or the
## player can't afford it.
func purchase_skin(skin_id: String, price: int) -> bool:
	if owns_skin(skin_id) or not MetaProgression.spend_echoes(price):
		return false
	_owned_skins.append(skin_id)
	_save()
	skins_changed.emit()
	return true


# --- Daily ad limit -----------------------------------------------------------

func ads_watched_today() -> int:
	_roll_day_if_needed()
	return _ads_watched_today


func ads_left_today() -> int:
	return maxi(DAILY_AD_LIMIT - ads_watched_today(), 0)


func can_watch_ad_today() -> bool:
	return ads_left_today() > 0


## Call when a rewarded ad for a shard pays out: counts it toward today's
## limit and grants the shard.
func register_ad_reward() -> void:
	_roll_day_if_needed()
	_ads_watched_today += 1
	_save()
	daily_ads_changed.emit(_ads_watched_today, DAILY_AD_LIMIT)
	add_anchor_shards(1)


func _roll_day_if_needed() -> void:
	var today: String = Time.get_date_string_from_system()
	if _ads_date != today:
		_ads_date = today
		_ads_watched_today = 0
		_save()
		daily_ads_changed.emit(0, DAILY_AD_LIMIT)


## Re-reads the save file (after a cloud save replaced it).
func reload_from_disk() -> void:
	anchor_shards = 0
	_ads_watched_today = 0
	_ads_date = ""
	_owned_skins.clear()
	equipped_skin = "default"
	_load()
	anchor_shards_changed.emit(anchor_shards)
	skins_changed.emit()
	equipped_skin_changed.emit(equipped_skin)


## Empties the inventory (used when the account is deleted). The daily ad
## counter is kept, so deleting an account doesn't reset the ad limit.
func reset_progress() -> void:
	anchor_shards = 0
	_owned_skins.clear()
	equipped_skin = "default"
	_save()
	anchor_shards_changed.emit(anchor_shards)
	skins_changed.emit()
	equipped_skin_changed.emit(equipped_skin)


# --- Saving -------------------------------------------------------------------

func _load() -> void:
	var save_file := ConfigFile.new()
	var error: Error = save_file.load(SAVE_PATH)
	if error == OK:
		anchor_shards = maxi(int(save_file.get_value(SAVE_SECTION, "anchor_shards", 0)), 0)
		_ads_watched_today = maxi(int(save_file.get_value(SAVE_SECTION, "ads_watched_today", 0)), 0)
		_ads_date = str(save_file.get_value(SAVE_SECTION, "ads_date", ""))
		for skin_id in save_file.get_value(SAVE_SECTION, "owned_skins", []):
			_owned_skins.append(str(skin_id))
		equipped_skin = str(save_file.get_value(SAVE_SECTION, "equipped_skin", "default"))
		if not owns_skin(equipped_skin):
			equipped_skin = "default"
	elif error != ERR_FILE_NOT_FOUND:
		push_warning("Could not load inventory save: %s" % error_string(error))
	_roll_day_if_needed()


func _save() -> void:
	var save_file := ConfigFile.new()
	save_file.set_value(SAVE_SECTION, "version", SAVE_VERSION)
	save_file.set_value(SAVE_SECTION, "anchor_shards", anchor_shards)
	save_file.set_value(SAVE_SECTION, "ads_watched_today", _ads_watched_today)
	save_file.set_value(SAVE_SECTION, "ads_date", _ads_date)
	save_file.set_value(SAVE_SECTION, "owned_skins", _owned_skins)
	save_file.set_value(SAVE_SECTION, "equipped_skin", equipped_skin)
	var error: Error = save_file.save(SAVE_PATH)
	if error != OK:
		push_error("Could not save inventory: %s" % error_string(error))
