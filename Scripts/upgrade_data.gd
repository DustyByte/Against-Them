extends RefCounted

## Permanent upgrades bought with Echoes on the Upgrades screen.
##
## `steps` is what each rank adds, in the units of the description (percent
## for "%" upgrades), so the number of ranks is steps.size(). The steps start
## small and grow by roughly the same factor each rank (the last about 5x the
## first): buying deeper into a track pays off more. Economy stays linear.
## `description` shows the upgrade's total with %s filled in (see
## describe()); one without %s is shown as written.
##
## Cost of buying the next rank when `rank` ranks are already owned grows
## exponentially, rounded to the nearest 5:
##     base_cost * cost_growth ^ rank
## Growth is set by how many ranks an upgrade has, so the last rank of a long
## track doesn't explode: 10 ranks x1.35, 8 ranks x1.4, 6 ranks x1.5,
## 5 ranks x1.6, 4 ranks x1.75, 3 ranks x2 (e.g. 250 / 500 / 1000). Capstones
## are a single expensive rank.
## e.g. Vitality: 25, 35, 45, 60, 85, 110, 150, 205, 275, 370.

const CATEGORIES: Array[String] = [
	"Survival",
	"Utility",
	"Weapons",
	"Rupture",
	"Torcher",
	"Elemental & Status",
	"Economy",
]

const UPGRADES: Array[Dictionary] = [
	# --- Survival ----------------------------------------------------------------
	{ "id": "vitality", "category": "Survival", "title": "Vitality", "description": "+%s max HP", "steps": [8, 9, 12, 13, 16, 19, 23, 28, 33, 39], "base_cost": 25, "cost_growth": 1.35 },
	{ "id": "resilience", "category": "Survival", "title": "Resilience", "description": "-%s%% incoming damage", "steps": [2, 3, 5, 8, 12], "base_cost": 50, "cost_growth": 1.6 },
	{ "id": "regeneration", "category": "Survival", "title": "Regeneration", "description": "+%s HP every 3 seconds", "steps": [0.2, 0.4, 0.5, 0.8, 1.1], "base_cost": 40, "cost_growth": 1.6 },
	{ "id": "recovery", "category": "Survival", "title": "Recovery", "description": "+%s%% healing received", "steps": [2, 3, 5, 10], "base_cost": 40, "cost_growth": 1.75 },

	# --- Utility -----------------------------------------------------------------
	{ "id": "swiftness", "category": "Utility", "title": "Swiftness", "description": "+%s movement speed", "steps": [8, 11, 17, 26, 38], "base_cost": 35, "cost_growth": 1.6 },
	{ "id": "magnetism", "category": "Utility", "title": "Magnetism", "description": "+%s%% pickup radius", "steps": [3, 4, 6, 9, 13], "base_cost": 25, "cost_growth": 1.6 },
	{ "id": "fortune", "category": "Utility", "title": "Fortune", "description": "+%s%% EXP gain", "steps": [6, 7, 8, 10, 12, 14, 17, 21, 25, 30], "base_cost": 40, "cost_growth": 1.35 },
	{ "id": "extra_choice", "category": "Utility", "title": "Extra Choice", "description": "+1 option on every level-up", "steps": [1], "base_cost": 2000, "cost_growth": 1.0 },

	# --- Weapons (general: pricier than weapon-specific upgrades) ----------------
	{ "id": "sharpened", "category": "Weapons", "title": "Sharpened", "description": "+%s%% weapon damage", "steps": [4, 5, 6, 7, 8, 9, 11, 14, 16, 20], "base_cost": 50, "cost_growth": 1.35 },
	{ "id": "rapid_fire", "category": "Weapons", "title": "Rapid Fire", "description": "+%s%% weapon attack speed", "steps": [1, 1.5, 1.5, 2, 2.5, 3, 3.5, 5], "base_cost": 50, "cost_growth": 1.4 },
	{ "id": "fast_hands", "category": "Weapons", "title": "Fast Hands", "description": "-%s%% reload time", "steps": [1.5, 2.5, 3.5, 5, 7.5], "base_cost": 45, "cost_growth": 1.6 },
	{ "id": "ammo_belt", "category": "Weapons", "title": "Ammo Belt", "description": "+%s max ammo for every weapon", "steps": [1, 2, 3], "base_cost": 250, "cost_growth": 2.0 },
	{ "id": "impact", "category": "Weapons", "title": "Impact", "description": "+%s%% knockback", "steps": [3, 4, 5, 7, 9, 12], "base_cost": 35, "cost_growth": 1.5 },
	{ "id": "boss_bane", "category": "Weapons", "title": "Boss Bane", "description": "+%s%% damage to bosses", "steps": [4, 6, 8, 13, 19], "base_cost": 50, "cost_growth": 1.6 },

	# --- Rupture -----------------------------------------------------------------
	{ "id": "rupture_caliber", "category": "Rupture", "title": "Caliber", "description": "+%s%% Rupture damage", "steps": [4, 6, 8, 13, 19], "base_cost": 25, "cost_growth": 1.6 },
	{ "id": "rupture_extended_mag", "category": "Rupture", "title": "Extended Mag", "description": "+%s Rupture max ammo", "steps": [1, 2, 3], "base_cost": 40, "cost_growth": 2.0 },
	{ "id": "rupture_quickdraw", "category": "Rupture", "title": "Quickdraw", "description": "+%s%% Rupture attack speed", "steps": [2.5, 3.5, 5, 7.5, 11.5], "base_cost": 25, "cost_growth": 1.6 },
	{ "id": "rupture_fast_reload", "category": "Rupture", "title": "Fast Reload", "description": "-%s%% Rupture reload time", "steps": [2, 2.5, 4, 5, 7, 9.5], "base_cost": 25, "cost_growth": 1.5 },

	# --- Torcher -----------------------------------------------------------------
	{ "id": "torcher_fuel", "category": "Torcher", "title": "Fuel", "description": "+%s%% Torcher damage", "steps": [3, 4, 5, 7, 9, 11, 14, 17], "base_cost": 25, "cost_growth": 1.4 },
	{ "id": "torcher_ignition", "category": "Torcher", "title": "Ignition", "description": "+%s%% Torcher burn damage", "steps": [5, 6, 8, 10, 12, 15, 20, 24], "base_cost": 25, "cost_growth": 1.4 },
	{ "id": "torcher_lingering_flame", "category": "Torcher", "title": "Lingering Flame", "description": "+%s%% burn duration", "steps": [3, 5, 7, 10, 15], "base_cost": 25, "cost_growth": 1.6 },
	{ "id": "torcher_ammo_tank", "category": "Torcher", "title": "Ammo Tank", "description": "+%s Torcher max ammo", "steps": [1, 2, 3, 4], "base_cost": 40, "cost_growth": 1.75 },
	{ "id": "torcher_backdraft", "category": "Torcher", "title": "Backdraft", "description": "+%s%% Torcher knockback", "steps": [2, 3, 5.5, 9.5], "base_cost": 20, "cost_growth": 1.75 },

	# --- Elemental & status ------------------------------------------------------
	{ "id": "pyromancy", "category": "Elemental & Status", "title": "Pyromancy", "description": "+%s%% burn damage", "steps": [2.5, 3, 4, 5, 6, 7.5, 10, 12], "base_cost": 40, "cost_growth": 1.4 },
	{ "id": "cryomancy", "category": "Elemental & Status", "title": "Cryomancy", "description": "+%s%% freeze duration", "steps": [2.5, 3, 4, 5, 6, 7.5, 10, 12], "base_cost": 40, "cost_growth": 1.4 },
	{ "id": "hemomancy", "category": "Elemental & Status", "title": "Hemomancy", "description": "+%s%% bleed damage", "steps": [2.5, 3, 4, 5, 6, 7.5, 10, 12], "base_cost": 40, "cost_growth": 1.4 },
	{ "id": "electromancy", "category": "Elemental & Status", "title": "Electromancy", "description": "+%s%% lightning damage", "steps": [2.5, 3, 4, 5, 6, 7.5, 10, 12], "base_cost": 40, "cost_growth": 1.4 },

	# --- Economy (linear) --------------------------------------------------------
	{ "id": "harvest", "category": "Economy", "title": "Harvest", "description": "+%s Echoes per 200 kills", "steps": [1, 1, 1, 1, 1], "base_cost": 75, "cost_growth": 1.6 },
	{ "id": "boss_bounty", "category": "Economy", "title": "Boss Bounty", "description": "+%s Echoes from each boss", "steps": [1, 1, 1], "base_cost": 100, "cost_growth": 2.0 },
]


## Echoes needed to buy the next rank when `rank` ranks are already owned.
static func cost_for_next_rank(upgrade: Dictionary, rank: int) -> int:
	var raw: float = upgrade["base_cost"] * pow(upgrade["cost_growth"], rank)
	return int(roundf(raw / 5.0)) * 5


static func max_rank(upgrade: Dictionary) -> int:
	return upgrade["steps"].size()


## What the first `rank` ranks add up to, in the description's units.
static func total_at(upgrade: Dictionary, rank: int) -> float:
	var total: float = 0.0
	for i in mini(rank, upgrade["steps"].size()):
		total += upgrade["steps"][i]
	return total


## The card's description at `rank`: the next rank's total at rank 0, the
## current total and the next one ("+12 » 21 max HP") partway, and the full
## total once maxed.
static func describe(upgrade: Dictionary, rank: int) -> String:
	var template: String = TranslationServer.translate(upgrade["description"])
	if not template.contains("%s"):
		return template
	var top: int = max_rank(upgrade)
	if rank <= 0:
		return template % _number(total_at(upgrade, 1))
	if rank >= top:
		return template % _number(total_at(upgrade, top))
	return template % (_number(total_at(upgrade, rank)) + " » " + _number(total_at(upgrade, rank + 1)))


static func _number(value: float) -> String:
	value = snappedf(value, 0.1)
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
