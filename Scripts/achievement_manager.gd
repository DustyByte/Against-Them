extends Node

## Tracks achievement progress, saves it, and pays out Echoes on claim.
## Registered as the "AchievementManager" autoload.
##
## Progress is stored as named counters ("stats"). Each achievement in
## achievement_data.gd names the stat it reads with its "stat" key.
## Run achievements read a "best_..." stat, the best value reached in any single
## run, so once one is completed it stays completed.
##
## Kill attribution: damage dealers call hit() (or push_source()/pop_source()
## around their own get_hit calls) so the manager knows which weapon, summon or
## effect dealt the killing blow.

signal achievement_completed(achievement_id: String)
signal achievement_claimed(achievement_id: String)

const AchievementData = preload("res://Scripts/achievement_data.gd")

const SAVE_PATH: String = "user://achievements.cfg"
const SAVE_SECTION_STATS: String = "stats"
const SAVE_SECTION_CLAIMED: String = "claimed"
const SAVE_VERSION: int = 1
const SAVE_INTERVAL_SECONDS: float = 5.0

const KILL_BURST_WINDOW_MSEC: int = 1000
const DEATH_COUNTED_META: StringName = &"_achievement_death_counted"
const BOSS_SPAWN_TIME_META: StringName = &"_achievement_boss_spawn_time"
const BOSS_SPAWN_DAMAGE_META: StringName = &"_achievement_boss_spawn_damage"
const BOSS_SPEED_KILL_SECONDS: float = 10.0

# Damage sources. Kills are counted per source in the stat "kills_<source>".
const SOURCE_RUPTURE: StringName = &"rupture"
const SOURCE_TORCHER: StringName = &"torcher"
const SOURCE_LIGHTNING: StringName = &"lightning" # Lightning Strike and Hexa Snail
const SOURCE_SILVER_STORM: StringName = &"silver_storm"
const SOURCE_RECALL_DAGGER: StringName = &"recall_dagger"
const SOURCE_STAR: StringName = &"star"
const SOURCE_BLACK_HOLE: StringName = &"black_hole"
const SOURCE_LASER_ORB: StringName = &"laser_orb"
const SOURCE_GRAVITY_BOMB: StringName = &"gravity_bomb"
const SOURCE_FIERY_FIELD: StringName = &"fiery_field"
const SOURCE_CRYOLITE: StringName = &"cryolite"
const SOURCE_RETRIBUTION: StringName = &"retribution"
const SOURCE_AURA: StringName = &"aura"
const SOURCE_BURN: StringName = &"burn"
const SOURCE_BLEED: StringName = &"bleed"
const SOURCE_EXPLOSION: StringName = &"explosion"

const WEAPON_SOURCES: Array[StringName] = [SOURCE_RUPTURE, SOURCE_TORCHER]
const SUMMON_SOURCES: Array[StringName] = [
	SOURCE_LIGHTNING, SOURCE_SILVER_STORM, SOURCE_RECALL_DAGGER, SOURCE_STAR,
	SOURCE_BLACK_HOLE, SOURCE_LASER_ORB, SOURCE_GRAVITY_BOMB, SOURCE_FIERY_FIELD,
	SOURCE_CRYOLITE, SOURCE_RETRIBUTION, SOURCE_AURA,
]

# Level-up options that give the player a summon.
const SUMMON_OPTIONS: Array[String] = [
	"Lightning Strike", "Hexa Snail", "Retribution", "Silver Storm", "Recall Dagger",
	"Aura", "Miniature Star", "Laser Orb", "Gravity Bomb", "Fiery Field", "Cryolite",
]

var _stats: Dictionary = {}
var _claimed_ids: Dictionary = {}
var _by_id: Dictionary = {}
# stat -> Array of tracked achievements reading it that are not completed yet.
var _pending_by_stat: Dictionary = {}
var _changed_stats: Dictionary = {}

# Current-run state. Not saved; reset by start_run().
var _run_seconds: float = 0.0
var _run_kills: int = 0
var _run_boss_kills: int = 0
var _run_source_kills: Dictionary = {}
var _recent_kill_times: Array[int] = []
var _run_waves_completed: int = 0
var _run_flawless_waves: int = 0
var _damaged_this_wave: bool = false
var _damaged_this_run: bool = false
var _player_damage_count: int = 0
var _seconds_at_one_hp: float = 0.0
var _run_weapons_fired: Dictionary = {}
var _run_option_picks: Dictionary = {}
var _run_summon_picks: int = 0
var _run_picked_life_or_regen: bool = false
var _run_revived: bool = false
var _frozen_now: int = 0

var _source_stack: Array[StringName] = []
# One entry per explosion currently dealing damage: { "kills": int }.
var _explosion_stack: Array[Dictionary] = []

var _dirty: bool = false
var _save_timer: Timer


func _ready() -> void:
	for achievement: Dictionary in AchievementData.ACHIEVEMENTS:
		_by_id[achievement["id"]] = achievement
		if achievement.has("stat"):
			var stat: String = achievement["stat"]
			if not _pending_by_stat.has(stat):
				_pending_by_stat[stat] = []
			_pending_by_stat[stat].append(achievement)

	var had_echo_stats: bool = load_progress()
	if not had_echo_stats:
		# Echoes earned before achievements existed: count at least what is held now.
		_raise_stat("echoes_earned", MetaProgression.echoes)
	_raise_stat("most_echoes_held", MetaProgression.echoes)

	_changed_stats = _pending_by_stat.duplicate()
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
	_run_seconds = 0.0
	_run_kills = 0
	_run_boss_kills = 0
	_run_source_kills.clear()
	_recent_kill_times.clear()
	_run_waves_completed = 0
	_run_flawless_waves = 0
	_damaged_this_wave = false
	_damaged_this_run = false
	_player_damage_count = 0
	_seconds_at_one_hp = 0.0
	_run_weapons_fired.clear()
	_run_option_picks.clear()
	_run_summon_picks = 0
	_run_picked_life_or_regen = false
	_run_revived = false
	_frozen_now = 0
	_source_stack.clear()
	_explosion_stack.clear()
	_save_if_dirty()


## Call every frame of a run with the run clock and the player's HP.
func register_run_time(elapsed_seconds: float, delta: float, player_hp: float) -> void:
	_run_seconds = elapsed_seconds
	_raise_stat("best_run_seconds", int(elapsed_seconds))

	if _is_at_one_hp(player_hp):
		_seconds_at_one_hp += delta
		_raise_stat("best_seconds_at_1hp", int(_seconds_at_one_hp))
	else:
		_seconds_at_one_hp = 0.0

	_refresh_completed(true)


## Call when the descend ends and its results are shown.
func register_run_completed() -> void:
	_add_stat("runs_completed", 1)
	_refresh_completed(true)


## Call when the player is revived after dying.
func register_revive() -> void:
	_run_revived = true


# --- Damage attribution ------------------------------------------------------

## Deals damage to an enemy while recording which source dealt it.
func hit(enemy: Node, damage: float, source: StringName, emit_hit_signal: bool = true) -> float:
	push_source(source)
	var remaining_hp: float = enemy.get_hit(damage, emit_hit_signal)
	pop_source()
	return remaining_hp


## For code that calls get_hit itself: everything between push and pop is
## credited to `source`.
func push_source(source: StringName) -> void:
	_source_stack.push_back(source)


func pop_source() -> void:
	if not _source_stack.is_empty():
		_source_stack.pop_back()


## Credits every kill until end_explosion() to one explosion (for Chain Reaction).
## Kills keep the source already active (e.g. an Overload explosion stays
## Lightning); with none active they are credited to SOURCE_EXPLOSION.
func begin_explosion() -> void:
	_explosion_stack.push_back({ "kills": 0 })
	push_source(SOURCE_EXPLOSION if _source_stack.is_empty() else _source_stack.back())


func end_explosion() -> void:
	if not _explosion_stack.is_empty():
		_explosion_stack.pop_back()
		pop_source()


func _current_source() -> StringName:
	return _source_stack.back() if not _source_stack.is_empty() else &""


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

	var source: StringName = _current_source()

	_run_kills += 1
	_add_stat("lifetime_kills", 1)
	_raise_stat("best_run_kills", _run_kills)

	var now: int = Time.get_ticks_msec()
	_recent_kill_times.append(now)
	while not _recent_kill_times.is_empty() and now - _recent_kill_times[0] >= KILL_BURST_WINDOW_MSEC:
		_recent_kill_times.pop_front()
	_raise_stat("best_kills_in_one_second", _recent_kill_times.size())

	if source != &"":
		_add_stat("kills_%s" % source, 1)
		_run_source_kills[source] = int(_run_source_kills.get(source, 0)) + 1
		# The black hole is the Miniature Star's final form.
		if source == SOURCE_BLACK_HOLE:
			_add_stat("kills_%s" % SOURCE_STAR, 1)
			_raise_stat("best_run_black_hole_kills", _run_source_kills[source])
		if source in WEAPON_SOURCES:
			_raise_stat("best_run_dual_weapon_kills", mini(
				int(_run_source_kills.get(SOURCE_RUPTURE, 0)),
				int(_run_source_kills.get(SOURCE_TORCHER, 0))))

	var marks = enemy.get("marks")
	if marks is Dictionary and marks.has("freeze"):
		_add_stat("frozen_kills", 1)

	if not _explosion_stack.is_empty():
		var explosion: Dictionary = _explosion_stack.back()
		explosion["kills"] += 1
		_raise_stat("best_explosion_kills", explosion["kills"])

	if enemy.get("asBoss") == true:
		_register_boss_kill(enemy, source)

	_refresh_completed(true)


func _register_boss_kill(boss: Node, source: StringName) -> void:
	_run_boss_kills += 1
	_add_stat("boss_kills", 1)
	_raise_stat("best_run_boss_kills", _run_boss_kills)

	if source in SUMMON_SOURCES:
		_add_stat("boss_summon_kills", 1)

	if boss.has_meta(BOSS_SPAWN_DAMAGE_META) and int(boss.get_meta(BOSS_SPAWN_DAMAGE_META)) == _player_damage_count:
		_add_stat("boss_clean_kills", 1)

	if boss.has_meta(BOSS_SPAWN_TIME_META) and _run_seconds - float(boss.get_meta(BOSS_SPAWN_TIME_META)) <= BOSS_SPEED_KILL_SECONDS:
		_add_stat("boss_speed_kills", 1)

	if source in WEAPON_SOURCES:
		_add_stat("boss_kills_%s" % source, 1)
		_raise_stat("best_weapon_boss_kills", int(_stats.get("boss_kills_%s" % source, 0)))


## Call when an enemy is made a boss.
func register_boss_spawned(boss: Node) -> void:
	boss.set_meta(BOSS_SPAWN_TIME_META, _run_seconds)
	boss.set_meta(BOSS_SPAWN_DAMAGE_META, _player_damage_count)


## Call for every instance of damage dealt to an enemy.
func register_enemy_hit(damage: float) -> void:
	# Instant-kill effects pass INF; those are not a real "hit" for Overkill.
	if not is_finite(damage) or damage <= float(_stats.get("biggest_hit", 0)):
		return

	_raise_stat("biggest_hit", int(damage))
	_refresh_completed(true)


## Call when a wave starts (its wave banner appears).
func register_wave_begun(wave: int) -> void:
	_raise_stat("best_wave_reached", wave)
	if _run_weapons_fired.size() <= 1:
		_raise_stat("best_wave_one_weapon", wave)
	if _run_summon_picks == 0:
		_raise_stat("best_wave_no_summon", wave)
	if not _run_picked_life_or_regen:
		_raise_stat("best_wave_no_life_regen", wave)
	if not _run_revived:
		_raise_stat("best_wave_no_revive", wave)
	_refresh_completed(true)


## Call when every enemy of a wave has been killed.
## A wave counts as flawless if the player took no damage since the previous
## wave was completed (or since the run began, for wave 1).
func register_wave_completed(wave: int) -> void:
	_run_waves_completed += 1
	_raise_stat("best_run_waves_completed", _run_waves_completed)

	if not _damaged_this_wave:
		_run_flawless_waves += 1
		_raise_stat("best_run_flawless_waves", _run_flawless_waves)

	# Untouchable: no damage at all this run, so every wave up to this one was flawless.
	if not _damaged_this_run:
		_raise_stat("best_flawless_start_streak", wave)

	if is_instance_valid(global.PLAYER) and _is_at_one_hp(global.PLAYER.stats.currentHP):
		_add_stat("close_call_waves", 1)

	_damaged_this_wave = false
	_refresh_completed(true)


## Call whenever the player actually loses HP.
func register_player_damaged() -> void:
	_damaged_this_wave = true
	_damaged_this_run = true
	_player_damage_count += 1


## Call when the player shoots with a weapon.
func register_weapon_fired(weapon_name: String) -> void:
	_run_weapons_fired[weapon_name] = true


## Call when the player picks a level-up option.
func register_option_picked(option: Option) -> void:
	var picks: int = int(_run_option_picks.get(option.name, 0)) + 1
	_run_option_picks[option.name] = picks

	match option.name:
		"Faster":
			_raise_stat("best_run_faster_picks", picks)
		"Greed":
			_raise_stat("best_run_greed_picks", picks)
		"Life", "Regen":
			_run_picked_life_or_regen = true

	if option.name in SUMMON_OPTIONS:
		_run_summon_picks += 1
		_add_stat("summons_obtained", 1)
		_raise_stat("best_run_summons", _run_summon_picks)

	if _has_maxed_a_branch():
		_raise_stat("maxed_branches", 1)

	_refresh_completed(true)


## A branch is a starting option (hierarchy "I") and every upgrade under it.
## It is maxed out once every option in it has been picked this run.
## Single-option branches (nothing to upgrade) don't count.
func _has_maxed_a_branch() -> bool:
	var choice_system = global.PROGRESSION_CHOICE_SYSTEM
	if not is_instance_valid(choice_system):
		return false

	for option: Option in choice_system.allOptions:
		if option.hierarchyMark != "I" or option.children.is_empty():
			continue
		if _is_branch_fully_picked(option):
			return true
	return false


func _is_branch_fully_picked(option: Option) -> bool:
	if not _run_option_picks.has(option.name):
		return false
	for child: Option in option.children:
		if not _is_branch_fully_picked(child):
			return false
	return true


## Call when the player reaches a new level.
func register_level_reached(level: int) -> void:
	_raise_stat("best_run_level", level)
	_refresh_completed(true)


## Call every time burn is applied to an enemy.
func register_burn_applied() -> void:
	_add_stat("burns_applied", 1)
	_refresh_completed(true)


## Call when an enemy that wasn't frozen becomes frozen.
func register_freeze_applied() -> void:
	_add_stat("freezes_applied", 1)
	_refresh_completed(true)


## Call with +1 when a freeze effect starts and -1 when it ends.
func register_frozen_count_changed(change: int) -> void:
	_frozen_now = maxi(_frozen_now + change, 0)
	if change > 0:
		_raise_stat("best_frozen_at_once", _frozen_now)
		_refresh_completed(true)


## Call with the number of enemies one lightning strike has hit so far,
## counting the first target and every chained enemy.
func register_lightning_chain_hits(enemies_hit: int) -> void:
	_raise_stat("best_lightning_chain_hits", enemies_hit)
	_refresh_completed(true)


## Call with the number of different enemies hit by the shards of one icicle
## explosion so far (including shards from explosions it set off).
func register_icicle_explosion_spread(enemies_hit: int) -> void:
	_raise_stat("best_icicle_explosion_spread", enemies_hit)
	_refresh_completed(true)


## Call whenever Echoes are added. `total` is the amount now held.
func register_echoes_earned(amount: int, total: int) -> void:
	_add_stat("echoes_earned", amount)
	_raise_stat("most_echoes_held", total)
	_refresh_completed(true)


func _is_at_one_hp(hp: float) -> bool:
	# HP is a float; anything above 0 and up to 1 counts as "1 HP".
	return hp > 0.0 and hp <= 1.0


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
	_changed_stats[stat] = true
	_dirty = true


func _raise_stat(stat: String, value: int) -> void:
	if value > int(_stats.get(stat, 0)):
		_stats[stat] = value
		_changed_stats[stat] = true
		_dirty = true


func _refresh_completed(emit_and_save: bool) -> void:
	# Runs very often (every kill), so it only checks achievements whose stat changed.
	if _changed_stats.is_empty():
		return

	var newly_completed: bool = false
	for stat: String in _changed_stats.keys():
		var pending: Array = _pending_by_stat.get(stat, [])
		for i: int in range(pending.size() - 1, -1, -1):
			var id: String = pending[i]["id"]
			if is_completed(id):
				pending.remove_at(i)
				newly_completed = true
				if emit_and_save:
					achievement_completed.emit(id)
	_changed_stats.clear()

	# Save right away so a completion is never lost to a crash.
	if newly_completed and emit_and_save:
		save_progress()


func _find(achievement_id: String) -> Dictionary:
	return _by_id.get(achievement_id, {})


func _save_if_dirty() -> void:
	if _dirty:
		save_progress()


## Returns true if the save already tracked earned Echoes.
func load_progress() -> bool:
	var save_file := ConfigFile.new()
	var error: Error = save_file.load(SAVE_PATH)
	if error != OK:
		if error != ERR_FILE_NOT_FOUND:
			push_warning("Could not load achievements save: %s" % error_string(error))
		return false

	if save_file.has_section(SAVE_SECTION_STATS):
		for stat: String in save_file.get_section_keys(SAVE_SECTION_STATS):
			if stat != "version":
				_stats[stat] = maxi(int(save_file.get_value(SAVE_SECTION_STATS, stat, 0)), 0)

	if save_file.has_section(SAVE_SECTION_CLAIMED):
		for id: String in save_file.get_section_keys(SAVE_SECTION_CLAIMED):
			if save_file.get_value(SAVE_SECTION_CLAIMED, id, false):
				_claimed_ids[id] = true

	return _stats.has("echoes_earned")


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
