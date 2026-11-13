extends RefCounted

## Permanent upgrades bought with Echoes on the Upgrades screen.
## Data only: nothing here changes gameplay yet.
##
## Cost of buying the next rank when `rank` ranks are already owned grows
## exponentially, rounded to the nearest 5:
##     base_cost * cost_growth ^ rank
## Growth is set by how many ranks an upgrade has, so the last rank of a long
## track doesn't explode: 10 ranks x1.35, 8 ranks x1.4, 5 ranks x1.6,
## 4 ranks x1.75, 3 ranks x2 (e.g. 250 / 500 / 1000). Capstones are a single
## expensive rank.
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
	# --- Survival -------------------------------------------------------------
	{ "id": "vitality", "category": "Survival", "title": "Vitality", "description": "+5 max HP per rank", "max_rank": 10, "base_cost": 25, "cost_growth": 1.35 },
	{ "id": "resilience", "category": "Survival", "title": "Resilience", "description": "-1% incoming damage per rank", "max_rank": 5, "base_cost": 50, "cost_growth": 1.6 },
	{ "id": "regeneration", "category": "Survival", "title": "Regeneration", "description": "+0.1 HP every 3 seconds per rank", "max_rank": 5, "base_cost": 40, "cost_growth": 1.6 },
	{ "id": "recovery", "category": "Survival", "title": "Recovery", "description": "+5% healing received per rank", "max_rank": 4, "base_cost": 40, "cost_growth": 1.75 },

	# --- Utility -------------------------------------------------------------
	{ "id": "swiftness", "category": "Utility", "title": "Swiftness", "description": "+2% movement speed per rank", "max_rank": 5, "base_cost": 35, "cost_growth": 1.6 },
	{ "id": "magnetism", "category": "Utility", "title": "Magnetism", "description": "+5% pickup radius per rank", "max_rank": 5, "base_cost": 25, "cost_growth": 1.6 },
	{ "id": "fortune", "category": "Utility", "title": "Fortune", "description": "+3% EXP gain per rank", "max_rank": 5, "base_cost": 40, "cost_growth": 1.6 },
	{ "id": "extra_choice", "category": "Utility", "title": "Extra Choice", "description": "+1 option on every level-up", "max_rank": 1, "base_cost": 2000, "cost_growth": 1.0 },

	# --- Weapons (general: pricier than weapon-specific upgrades) -------------
	{ "id": "sharpened", "category": "Weapons", "title": "Sharpened", "description": "+2% weapon damage per rank", "max_rank": 10, "base_cost": 50, "cost_growth": 1.35 },
	{ "id": "rapid_fire", "category": "Weapons", "title": "Rapid Fire", "description": "+1.5% weapon attack speed per rank", "max_rank": 8, "base_cost": 50, "cost_growth": 1.4 },
	{ "id": "fast_hands", "category": "Weapons", "title": "Fast Hands", "description": "-2% reload time per rank", "max_rank": 5, "base_cost": 45, "cost_growth": 1.6 },
	{ "id": "ammo_belt", "category": "Weapons", "title": "Ammo Belt", "description": "+1 max ammo for every weapon per rank", "max_rank": 3, "base_cost": 250, "cost_growth": 2.0 },
	{ "id": "impact", "category": "Weapons", "title": "Impact", "description": "+5% knockback per rank", "max_rank": 4, "base_cost": 35, "cost_growth": 1.75 },
	{ "id": "boss_bane", "category": "Weapons", "title": "Boss Bane", "description": "+2% damage to bosses per rank", "max_rank": 5, "base_cost": 50, "cost_growth": 1.6 },

	# --- Rupture --------------------------------------------------------------
	{ "id": "rupture_caliber", "category": "Rupture", "title": "Caliber", "description": "+2% Rupture damage per rank", "max_rank": 5, "base_cost": 25, "cost_growth": 1.6 },
	{ "id": "rupture_extended_mag", "category": "Rupture", "title": "Extended Mag", "description": "+1 Rupture max ammo per rank", "max_rank": 5, "base_cost": 40, "cost_growth": 1.6 },
	{ "id": "rupture_quickdraw", "category": "Rupture", "title": "Quickdraw", "description": "+2% Rupture attack speed per rank", "max_rank": 5, "base_cost": 25, "cost_growth": 1.6 },
	{ "id": "rupture_fast_reload", "category": "Rupture", "title": "Fast Reload", "description": "-3% Rupture reload time per rank", "max_rank": 4, "base_cost": 25, "cost_growth": 1.75 },

	# --- Torcher --------------------------------------------------------------
	{ "id": "torcher_fuel", "category": "Torcher", "title": "Fuel", "description": "+3% Torcher damage per rank", "max_rank": 5, "base_cost": 25, "cost_growth": 1.6 },
	{ "id": "torcher_ignition", "category": "Torcher", "title": "Ignition", "description": "+3% Torcher burn damage per rank", "max_rank": 5, "base_cost": 25, "cost_growth": 1.6 },
	{ "id": "torcher_lingering_flame", "category": "Torcher", "title": "Lingering Flame", "description": "+5% burn duration per rank", "max_rank": 5, "base_cost": 25, "cost_growth": 1.6 },
	{ "id": "torcher_ammo_tank", "category": "Torcher", "title": "Ammo Tank", "description": "+1 Torcher max ammo per rank", "max_rank": 5, "base_cost": 40, "cost_growth": 1.6 },
	{ "id": "torcher_backdraft", "category": "Torcher", "title": "Backdraft", "description": "+10% knockback per rank", "max_rank": 4, "base_cost": 20, "cost_growth": 1.75 },

	# --- Elemental & status ---------------------------------------------------
	{ "id": "pyromancy", "category": "Elemental & Status", "title": "Pyromancy", "description": "+3% burn damage per rank", "max_rank": 5, "base_cost": 40, "cost_growth": 1.6 },
	{ "id": "cryomancy", "category": "Elemental & Status", "title": "Cryomancy", "description": "+3% freeze duration per rank", "max_rank": 5, "base_cost": 40, "cost_growth": 1.6 },
	{ "id": "hemomancy", "category": "Elemental & Status", "title": "Hemomancy", "description": "+3% bleed damage per rank", "max_rank": 5, "base_cost": 40, "cost_growth": 1.6 },
	{ "id": "electromancy", "category": "Elemental & Status", "title": "Electromancy", "description": "+3% lightning damage per rank", "max_rank": 5, "base_cost": 40, "cost_growth": 1.6 },

	# --- Economy --------------------------------------------------------------
	{ "id": "harvest", "category": "Economy", "title": "Harvest", "description": "+1 Echoe per 200 kills per rank", "max_rank": 5, "base_cost": 75, "cost_growth": 1.6 },
	{ "id": "boss_bounty", "category": "Economy", "title": "Boss Bounty", "description": "+1 Echoe from each boss per rank", "max_rank": 3, "base_cost": 100, "cost_growth": 2.0 },
]


## Echoes needed to buy the next rank when `rank` ranks are already owned.
static func cost_for_next_rank(upgrade: Dictionary, rank: int) -> int:
	var raw: float = upgrade["base_cost"] * pow(upgrade["cost_growth"], rank)
	return int(roundf(raw / 5.0)) * 5
