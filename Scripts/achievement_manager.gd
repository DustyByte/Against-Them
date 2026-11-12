extends Node

## Tracks achievement progress, saves it, and pays out Echoes on claim.
## Registered as the "AchievementManager" autoload.
##
## Progress is stored as a few counters ("stats"). Each achievement in
## achievement_data.gd names the stat it reads with its "stat" key; achievements
## without one are not implemented yet and always show 0 progress.
## Run achievements read a "best_..." stat, the best value reached in any single
## run, so once one is completed it stays completed.

signal achievement_completed(achievement_id: String)
signal achievement_claimed(achievement_id: String)

const AchievementData = preload("res://Scripts/achievement_data.gd")

const SAVE_PATH: String = "user://achievements.cfg"
const SAVE_SECTION_STATS: String = "stats"
const SAVE_SECTION_CLAIMED: String = "claimed"
const SAVE_VERSION: int = 1
const SAVE_INTERVAL_SECONDS: float = 5.0

# Stat keys. Run stats are "best in any single run".
const STAT_LIFETIME_KILLS: String = "lifetime_kills"
const STAT_BEST_RUN_KILLS: String = "best_run_kills"
const STAT_BEST_KILLS_IN_ONE_SECOND: String = "best_kills_in_one_second"
const STAT_BIGGEST_HIT: String = "biggest_hit"
const STAT_BEST_WAVE_REACHED: String = "best_wave_reached"
const STAT_BEST_RUN_WAVES_COMPLETED: String = "best_run_waves_completed"
const STAT_BEST_RUN_FLAWLESS_WAVES: String = "best_run_flawless_waves"
# Waves completed in a row from wave 1 without taking damage, best in any run.
const STAT_BEST_FLAWLESS_START_STREAK: String = "best_flawless_start_streak"

const KILL_BURST_WINDOW_MSEC: int = 1000
const DEATH_COUNTED_META: StringName = &"_achievement_death_counted"

var _stats: Dictionary = {
	STAT_LIFETIME_KILLS: 0,
	STAT_BEST_RUN_KILLS: 0,
	STAT_BEST_KILLS_IN_ONE_SECOND: 0,
	STAT_BIGGEST_HIT: 0,
	STAT_BEST_WAVE_REACHED: 0,
	STAT_BEST_RUN_WAVES_COMPLETED: 0,
	STAT_BEST_RUN_FLAWLESS_WAVES: 0,
	STAT_BEST_FLAWLESS_START_STREAK: 0,
}
var _claimed_ids: Dictionary = {}
var _by_id: Dictionary = {}
# Tracked (has a "stat") achievements that are not completed yet.
var _pending: Array[Dictionary] = []

# Current-run state. Not saved; reset by start_run().
var _run_kills: int = 0
var _recent_kill_times: Array[int] = []
var _run_waves_completed: int = 0
var _run_flawless_waves: int = 0
var _damaged_this_wave: bool = false
var _damaged_this_run: bool = false

var _dirty: bool = false
var _save_timer: Timer


func _ready() -> void:
	for achievement: Dictionary in AchievementData.ACHIEVEMENTS:
		_by_id[achievement["id"]] = achievement
		if achievement.has("stat"):
			_pending.append(achievement)

	load_progress()
	_refresh_completed(false)

	_save_timer = Timer.new()
	_save_timer.wait_time = SAVE_INTERVAL_SECONDS
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(_save_if_dirty)
	add_child(_save_timer)
	_save_timer.start()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_if_dirty()


# --- Run lifecycle -----------------------------------------------------------

## Call when a new descend starts.
func start_run() -> void:
	_run_kills = 0
	_recent_kill_times.clear()
	_run_waves_completed = 0
	_run_flawless_waves = 0
	_damaged_this_wave = false
	_damaged_this_run = false
	_save_if_dirty()


# --- Events from gameplay ----------------------------------------------------

## Call when an enemy actually dies. Safe to call more than once for the same
## enemy: only the first call counts. Pass counts_as_kill = false for deaths the
## player did not cause (e.g. an enemy blowing itself up on contact).
func register_enemy_death(enemy: Node, counts_as_kill: bool = true) -> void:
	if enemy.has_meta(DEATH_COUNTED_META):
		return
	enemy.set_meta(DEATH_COUNTED_META, true)

	if not counts_as_kill:
		return

	_run_kills += 1
	_add_stat(STAT_LIFETIME_KILLS, 1)
	_raise_stat(STAT_BEST_RUN_KILLS, _run_kills)

	var now: int = Time.get_ticks_msec()
	_recent_kill_times.append(now)
	while not _recent_kill_times.is_empty() and now - _recent_kill_times[0] >= KILL_BURST_WINDOW_MSEC:
		_recent_kill_times.pop_front()
	_raise_stat(STAT_BEST_KILLS_IN_ONE_SECOND, _recent_kill_times.size())

	_refresh_completed(true)


## Call when a wave starts (its wave banner appears).
func register_wave_begun(wave: int) -> void:
	_raise_stat(STAT_BEST_WAVE_REACHED, wave)
	_refresh_completed(true)


## Call when every enemy of a wave has been killed.
## A wave counts as flawless if the player took no damage since the previous
## wave was completed (or since the run began, for wave 1).
func register_wave_completed(wave: int) -> void:
	_run_waves_completed += 1
	_raise_stat(STAT_BEST_RUN_WAVES_COMPLETED, _run_waves_completed)

	if not _damaged_this_wave:
		_run_flawless_waves += 1
		_raise_stat(STAT_BEST_RUN_FLAWLESS_WAVES, _run_flawless_waves)

	# Untouchable: no damage at all this run, so every wave up to this one was flawless.
	if not _damaged_this_run:
		_raise_stat(STAT_BEST_FLAWLESS_START_STREAK, wave)

	_damaged_this_wave = false
	_refresh_completed(true)


## Call whenever the player actually loses HP.
func register_player_damaged() -> void:
	_damaged_this_wave = true
	_damaged_this_run = true


## Call for every instance of damage dealt to an enemy.
func register_enemy_hit(damage: float) -> void:
	# Instant-kill effects pass INF; those are not a real "hit" for Overkill.
	if not is_finite(damage) or damage <= float(_stats[STAT_BIGGEST_HIT]):
		return

	_raise_stat(STAT_BIGGEST_HIT, int(damage))
	_refresh_completed(true)


# --- Queries used by the achievements screen ---------------------------------

func get_progress(achievement_id: String) -> int:
	var achievement: Dictionary = _find(achievement_id)
	if achievement.is_empty() or not achievement.has("stat"):
		return 0

	var value: int = int(_stats.get(achievement["stat"], 0))
	var target: int = achievement["target"]

	# Yes/no achievements with a threshold, e.g. Overkill: biggest hit >= 1000 -> 1/1.
	if achievement.has("threshold"):
		return target if value >= int(achievement["threshold"]) else 0

	return mini(value, target)


## The achievement's entry from achievement_data.gd, or {} if the id is unknown.
func get_achievement(achievement_id: String) -> Dictionary:
	return _find(achievement_id)


func is_completed(achievement_id: String) -> bool:
	var achievement: Dictionary = _find(achievement_id)
	return not achievement.is_empty() and get_progress(achievement_id) >= int(achievement["target"])


func is_claimed(achievement_id: String) -> bool:
	return _claimed_ids.has(achievement_id)


## Pays out the reward. Returns the Echoes granted, or 0 if it can't be claimed.
func claim(achievement_id: String) -> int:
	if is_claimed(achievement_id) or not is_completed(achievement_id):
		return 0

	var reward: int = int(_find(achievement_id)["reward"])
	_claimed_ids[achievement_id] = true
	save_progress()
	MetaProgression.add_echoes(reward)
	achievement_claimed.emit(achievement_id)
	return reward


# --- Internals ---------------------------------------------------------------

func _add_stat(stat: String, amount: int) -> void:
	_stats[stat] = int(_stats.get(stat, 0)) + amount
	_dirty = true


func _raise_stat(stat: String, value: int) -> void:
	if value > int(_stats.get(stat, 0)):
		_stats[stat] = value
		_dirty = true


func _refresh_completed(emit_and_save: bool) -> void:
	# Runs on every kill, so it only walks the tracked achievements not yet completed.
	var newly_completed: bool = false
	for i: int in range(_pending.size() - 1, -1, -1):
		var id: String = _pending[i]["id"]
		if is_completed(id):
			_pending.remove_at(i)
			newly_completed = true
			if emit_and_save:
				achievement_completed.emit(id)

	# Save right away so a completion is never lost to a crash.
	if newly_completed and emit_and_save:
		save_progress()


func _find(achievement_id: String) -> Dictionary:
	return _by_id.get(achievement_id, {})


func _save_if_dirty() -> void:
	if _dirty:
		save_progress()


func load_progress() -> void:
	var save_file := ConfigFile.new()
	var error: Error = save_file.load(SAVE_PATH)
	if error != OK:
		if error != ERR_FILE_NOT_FOUND:
			push_warning("Could not load achievements save: %s" % error_string(error))
		return

	for stat: String in _stats.keys():
		_stats[stat] = maxi(int(save_file.get_value(SAVE_SECTION_STATS, stat, 0)), 0)

	if save_file.has_section(SAVE_SECTION_CLAIMED):
		for id: String in save_file.get_section_keys(SAVE_SECTION_CLAIMED):
			if save_file.get_value(SAVE_SECTION_CLAIMED, id, false):
				_claimed_ids[id] = true


func save_progress() -> void:
	var save_file := ConfigFile.new()
	save_file.set_value(SAVE_SECTION_STATS, "version", SAVE_VERSION)
	for stat: String in _stats.keys():
		save_file.set_value(SAVE_SECTION_STATS, stat, _stats[stat])
	for id: String in _claimed_ids.keys():
		save_file.set_value(SAVE_SECTION_CLAIMED, id, true)

	var error: Error = save_file.save(SAVE_PATH)
	if error != OK:
		push_error("Could not save achievements: %s" % error_string(error))
		return
	_dirty = false
