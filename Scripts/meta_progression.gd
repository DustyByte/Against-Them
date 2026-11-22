extends Node

signal echoes_changed(total: int)
signal echo_ads_changed(left: int, limit: int)
signal daily_reward_changed

const SAVE_PATH: String = "user://meta_progression.cfg"
const SAVE_SECTION: String = "meta_progression"
const SAVE_VERSION: int = 1

# Echo rewards are intentionally simple and transparent:
# each completed wave is worth a small amount, and each boss killed is worth
# more. Starting and immediately abandoning a run awards zero because no wave
# has actually been completed yet.
const ECHOES_PER_WAVE: int = 1
const ECHOES_PER_BOSS: int = 5

## Home screen Echoes notch: watch a rewarded ad for Echoes, a few times a day.
## The counter resets at local midnight and lives in this save, so it follows
## the account through cloud saves.
const AD_ECHOES_REWARD: int = 10
const DAILY_ECHO_AD_LIMIT: int = 7

## Daily transmission from Earth (Echo's ship on the Home screen holds it): one
## reward a day on a 7-day track. Missing a day doesn't reset the track, it
## just waits; after day 7 it starts over. A day starts at local midnight, and
## a clock turned back can't claim again (the last claim date must be passed).
const DAILY_REWARDS: Array[int] = [20, 25, 30, 40, 50, 60, 150]
## Anchor Shards (revives) given on top, per track day.
const DAILY_SHARDS: Array[int] = [0, 1, 0, 1, 0, 1, 2]

var echoes: int = 0
var _echo_ads_today: int = 0
var _echo_ads_date: String = ""   # local date ("YYYY-MM-DD") the counter belongs to
var _daily_claims: int = 0         # daily rewards claimed in all; the track day is this % 7
var _daily_last_claim: String = "" # local date of the last claim
var _daily_last_shown: String = "" # local date the card last opened by itself


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	var save_file := ConfigFile.new()
	var error: Error = save_file.load(SAVE_PATH)

	if error == OK:
		echoes = maxi(int(save_file.get_value(SAVE_SECTION, "echoes", 0)), 0)
		_echo_ads_today = maxi(int(save_file.get_value(SAVE_SECTION, "echo_ads_today", 0)), 0)
		_echo_ads_date = str(save_file.get_value(SAVE_SECTION, "echo_ads_date", ""))
		_daily_claims = maxi(int(save_file.get_value(SAVE_SECTION, "daily_claims", 0)), 0)
		_daily_last_claim = str(save_file.get_value(SAVE_SECTION, "daily_last_claim", ""))
		_daily_last_shown = str(save_file.get_value(SAVE_SECTION, "daily_last_shown", ""))
	else:
		echoes = 0
		_echo_ads_today = 0
		_echo_ads_date = ""
		_daily_claims = 0
		_daily_last_claim = ""
		_daily_last_shown = ""
		if error != ERR_FILE_NOT_FOUND:
			push_warning("Could not load meta progression save: %s" % error_string(error))


func save_progress() -> void:
	var save_file := ConfigFile.new()
	save_file.set_value(SAVE_SECTION, "version", SAVE_VERSION)
	save_file.set_value(SAVE_SECTION, "echoes", echoes)
	save_file.set_value(SAVE_SECTION, "echo_ads_today", _echo_ads_today)
	save_file.set_value(SAVE_SECTION, "echo_ads_date", _echo_ads_date)
	save_file.set_value(SAVE_SECTION, "daily_claims", _daily_claims)
	save_file.set_value(SAVE_SECTION, "daily_last_claim", _daily_last_claim)
	save_file.set_value(SAVE_SECTION, "daily_last_shown", _daily_last_shown)

	var error: Error = save_file.save(SAVE_PATH)
	if error != OK:
		push_error("Could not save meta progression: %s" % error_string(error))


func add_echoes(amount: int) -> void:
	if amount <= 0:
		return

	echoes += amount
	save_progress()
	echoes_changed.emit(echoes)
	AchievementManager.register_echoes_earned(amount, echoes)


## Re-reads the save file (after a cloud save replaced it).
func reload_from_disk() -> void:
	load_progress()
	echoes_changed.emit(echoes)
	echo_ads_changed.emit(echo_ads_left_today(), DAILY_ECHO_AD_LIMIT)
	daily_reward_changed.emit()


## Back to zero Echoes (used when the account is deleted). The daily ad
## counter and the daily reward track are kept, so deleting an account
## doesn't reset them.
func reset_progress() -> void:
	echoes = 0
	save_progress()
	echoes_changed.emit(echoes)


## Removes Echoes for a purchase. Returns false (and spends nothing) if the
## player doesn't have enough.
func spend_echoes(amount: int) -> bool:
	if amount < 0 or amount > echoes:
		return false

	echoes -= amount
	save_progress()
	echoes_changed.emit(echoes)
	return true


## Includes the Boss Bounty and Harvest upgrade bonuses.
func award_run_echoes(waves_completed: int, bosses_killed: int, kills: int = 0) -> int:
	var earned: int = (
		maxi(waves_completed, 0) * ECHOES_PER_WAVE
		+ maxi(bosses_killed, 0) * (ECHOES_PER_BOSS + UpgradeManager.boss_bounty_per_boss())
		+ UpgradeManager.harvest_echoes(kills)
	)

	add_echoes(earned)
	return earned


# --- Echoes for ads (daily limit) ---------------------------------------------

func echo_ads_left_today() -> int:
	_roll_echo_ad_day()
	return maxi(DAILY_ECHO_AD_LIMIT - _echo_ads_today, 0)


func can_watch_echo_ad() -> bool:
	return echo_ads_left_today() > 0


## Call when a rewarded ad watched for Echoes pays out: counts it toward
## today's limit and grants the Echoes. Returns false (and grants nothing) if
## today's limit was already used up.
func register_echo_ad_reward() -> bool:
	if not can_watch_echo_ad():
		return false
	_echo_ads_today += 1
	add_echoes(AD_ECHOES_REWARD)   # saves the counter too
	echo_ads_changed.emit(echo_ads_left_today(), DAILY_ECHO_AD_LIMIT)
	return true


## Seconds until local midnight, when the daily ad limit resets.
func seconds_until_echo_ad_reset() -> int:
	var now: Dictionary = Time.get_time_dict_from_system()
	return 86400 - (int(now.hour) * 3600 + int(now.minute) * 60 + int(now.second))


func _roll_echo_ad_day() -> void:
	var today: String = Time.get_date_string_from_system()
	if _echo_ads_date != today:
		_echo_ads_date = today
		_echo_ads_today = 0
		save_progress()
		echo_ads_changed.emit(DAILY_ECHO_AD_LIMIT, DAILY_ECHO_AD_LIMIT)


# --- Daily transmission -------------------------------------------------------

## True if today's reward is waiting (none claimed yet today).
func can_claim_daily_reward() -> bool:
	return Time.get_date_string_from_system() > _daily_last_claim   # "YYYY-MM-DD" sorts by date


## The track day (0-6) to show as today's: the one waiting to be claimed, or
## the one already claimed today.
func daily_reward_day() -> int:
	if can_claim_daily_reward():
		return _daily_claims % DAILY_REWARDS.size()
	return (_daily_claims - 1 + DAILY_REWARDS.size()) % DAILY_REWARDS.size()


## Claims today's reward: grants its Echoes (and Anchor Shards, on the days
## that have them) and moves the track on. Returns the Echoes granted (0 if
## today's was already claimed).
func claim_daily_reward() -> int:
	if not can_claim_daily_reward():
		return 0
	var day: int = _daily_claims % DAILY_REWARDS.size()
	var amount: int = DAILY_REWARDS[day]
	_daily_claims += 1
	_daily_last_claim = Time.get_date_string_from_system()
	add_echoes(amount)   # saves the track too
	if DAILY_SHARDS[day] > 0:
		InventoryManager.add_anchor_shards(DAILY_SHARDS[day])
	daily_reward_changed.emit()
	return amount


## True once a day, the first time the Home screen asks while today's reward
## is waiting: the card opens by itself then. Marks it as shown.
func should_show_daily_reward() -> bool:
	var today: String = Time.get_date_string_from_system()
	if not can_claim_daily_reward() or _daily_last_shown == today:
		return false
	_daily_last_shown = today
	save_progress()
	return true
