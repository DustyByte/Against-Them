extends Node

## Owns the permanent upgrades bought with Echoes: saves the rank of each
## upgrade, handles purchases, and gives gameplay code the resulting bonuses.
## Upgrade definitions (names, max ranks, prices) live in upgrade_data.gd.

signal rank_changed(upgrade_id: String, rank: int)

const UpgradeData = preload("res://Scripts/upgrade_data.gd")

const SAVE_PATH: String = "user://upgrades.cfg"
const SAVE_SECTION: String = "ranks"

## Base number of options offered on level-up, before Extra Choice.
const BASE_LEVEL_UP_OPTIONS: int = 6
const HARVEST_KILLS_PER_ECHO: int = 200
const REGENERATION_INTERVAL: float = 3.0

var _ranks: Dictionary = {} # upgrade id -> owned rank
var _by_id: Dictionary = {} # upgrade id -> definition


func _ready() -> void:
	for upgrade: Dictionary in UpgradeData.UPGRADES:
		_by_id[upgrade["id"]] = upgrade
	_load()


# --- Ranks and purchasing ----------------------------------------------------

func get_rank(upgrade_id: String) -> int:
	return _ranks.get(upgrade_id, 0)


func get_max_rank(upgrade_id: String) -> int:
	return _by_id[upgrade_id]["max_rank"]


func is_maxed(upgrade_id: String) -> bool:
	return get_rank(upgrade_id) >= get_max_rank(upgrade_id)


## Echoes needed for the next rank (0 when maxed).
func get_next_cost(upgrade_id: String) -> int:
	if is_maxed(upgrade_id):
		return 0
	return UpgradeData.cost_for_next_rank(_by_id[upgrade_id], get_rank(upgrade_id))


func can_afford(upgrade_id: String) -> bool:
	return not is_maxed(upgrade_id) and MetaProgression.echoes >= get_next_cost(upgrade_id)


## Spends the Echoes and raises the rank by one. Returns false (and changes
## nothing) if the upgrade is maxed or the player can't afford it.
func purchase(upgrade_id: String) -> bool:
	if not _by_id.has(upgrade_id) or not can_afford(upgrade_id):
		return false
	if not MetaProgression.spend_echoes(get_next_cost(upgrade_id)):
		return false

	var rank: int = get_rank(upgrade_id) + 1
	_ranks[upgrade_id] = rank
	_save()
	rank_changed.emit(upgrade_id, rank)
	return true


# --- Bonuses used by gameplay code -------------------------------------------

## Survival

func max_hp_bonus() -> float:
	return 5.0 * get_rank("vitality")


func damage_taken_multiplier() -> float:
	return 1.0 - 0.01 * get_rank("resilience")


## HP restored every REGENERATION_INTERVAL seconds.
func regeneration_per_tick() -> float:
	return 0.1 * get_rank("regeneration")


func healing_multiplier() -> float:
	return 1.0 + 0.05 * get_rank("recovery")


## Utility

func move_speed_multiplier() -> float:
	return 1.0 + 0.02 * get_rank("swiftness")


func pickup_radius_multiplier() -> float:
	return 1.0 + 0.05 * get_rank("magnetism")


func exp_multiplier() -> float:
	return 1.0 + 0.03 * get_rank("fortune")


func level_up_option_count() -> int:
	return BASE_LEVEL_UP_OPTIONS + get_rank("extra_choice")


## Weapons. Bonuses from the general Weapons upgrades and the weapon's own
## upgrades are added together (e.g. Sharpened 2 + Caliber 3 = +10% damage).

## Applies every weapon upgrade to a fresh copy of a weapon's base stats.
## `weapon` is "rupture" or "torcher".
func apply_weapon_upgrades(weapon: String, stats: Dictionary) -> Dictionary:
	var damage_bonus: float = 0.02 * get_rank("sharpened")
	var attack_speed_bonus: float = 0.015 * get_rank("rapid_fire")
	var reload_reduction: float = 0.02 * get_rank("fast_hands")
	var extra_ammo: int = get_rank("ammo_belt")
	var knockback_bonus: float = 0.05 * get_rank("impact")

	match weapon:
		"rupture":
			damage_bonus += 0.02 * get_rank("rupture_caliber")
			extra_ammo += get_rank("rupture_extended_mag")
			attack_speed_bonus += 0.02 * get_rank("rupture_quickdraw")
			reload_reduction += 0.03 * get_rank("rupture_fast_reload")
		"torcher":
			damage_bonus += 0.03 * get_rank("torcher_fuel")
			extra_ammo += get_rank("torcher_ammo_tank")
			knockback_bonus += 0.10 * get_rank("torcher_backdraft")

	stats.damage *= 1.0 + damage_bonus
	stats.cd /= 1.0 + attack_speed_bonus # faster attacks = shorter cooldown
	stats.reloadTime *= maxf(1.0 - reload_reduction, 0.1)
	stats.maxAmmo += extra_ammo
	stats.knockBackIntensity *= 1.0 + knockback_bonus
	stats[&"upgradeKnockBackMultiplier"] = 1.0 + knockback_bonus
	return stats


func boss_damage_multiplier() -> float:
	return 1.0 + 0.02 * get_rank("boss_bane")


## Torcher's own burns: Ignition stacks with Pyromancy (applied in burn_inflict).
func torcher_burn_damage_multiplier() -> float:
	return 1.0 + 0.03 * get_rank("torcher_ignition")


func torcher_burn_duration_multiplier() -> float:
	return 1.0 + 0.05 * get_rank("torcher_lingering_flame")


## Elemental & status (every source)

func burn_damage_multiplier() -> float:
	return 1.0 + 0.03 * get_rank("pyromancy")


func freeze_duration_multiplier() -> float:
	return 1.0 + 0.03 * get_rank("cryomancy")


func bleed_damage_multiplier() -> float:
	return 1.0 + 0.03 * get_rank("hemomancy")


func lightning_damage_multiplier() -> float:
	return 1.0 + 0.03 * get_rank("electromancy")


## Economy

func harvest_echoes(kills: int) -> int:
	return (maxi(kills, 0) / HARVEST_KILLS_PER_ECHO) * get_rank("harvest")


func boss_bounty_per_boss() -> int:
	return get_rank("boss_bounty")


# --- Saving ------------------------------------------------------------------

func _load() -> void:
	var file := ConfigFile.new()
	var error: Error = file.load(SAVE_PATH)
	if error != OK:
		if error != ERR_FILE_NOT_FOUND:
			push_warning("Could not load upgrades save: %s" % error_string(error))
		return

	for upgrade_id: String in _by_id:
		var rank: int = int(file.get_value(SAVE_SECTION, upgrade_id, 0))
		if rank > 0:
			_ranks[upgrade_id] = clampi(rank, 0, get_max_rank(upgrade_id))


func _save() -> void:
	var file := ConfigFile.new()
	for upgrade_id: String in _ranks:
		file.set_value(SAVE_SECTION, upgrade_id, _ranks[upgrade_id])
	var error: Error = file.save(SAVE_PATH)
	if error != OK:
		push_error("Could not save upgrades: %s" % error_string(error))
