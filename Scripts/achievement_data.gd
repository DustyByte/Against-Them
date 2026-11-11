extends RefCounted

## Static list of every achievement in the game. Progress is not tracked yet.
##
## Fields:
##   id       - stable key, used later for saving progress and claimed state.
##   category - heading the card is listed under.
##   type     - TYPE_RUN (must happen inside a single descend) or TYPE_LIFETIME
##              (accumulates across all descends).
##   title    - text shown on the card.
##   target   - number after the slash on the card. 1 means a yes/no achievement.
##   reward   - Echoes granted on claim.
##
## Reward scale: regular play earns roughly 3 Echoes per minute (about 90 per
## 30 minutes), so a reward is sized to the play time and skill it usually takes:
##   5        happens on its own in the first minutes
##   10 - 20  one normal descend, or a light condition
##   25 - 40  a long descend, or a real skill/build condition
##   50 - 100 several hours of play, or a hard challenge
##   150+     the long-term grinds and the wave-100 runs

const TYPE_RUN: String = "run"
const TYPE_LIFETIME: String = "lifetime"

const CATEGORIES: Array[String] = [
	"Enemy Kills",
	"Wave Milestones",
	"Survival",
	"Bosses",
	"Weapons",
	"Summons",
	"Status Effects",
	"Build & Upgrades",
	"Echoes & Meta Progression",
	"Challenges",
]

const ACHIEVEMENTS: Array[Dictionary] = [
	# Enemy kills
	{ "id": "first_blood", "category": "Enemy Kills", "type": TYPE_LIFETIME, "title": "Kill 1 enemy", "target": 1, "reward": 5 },
	{ "id": "century", "category": "Enemy Kills", "type": TYPE_LIFETIME, "title": "Kill 100 enemies", "target": 100, "reward": 10 },
	{ "id": "thousand_cuts", "category": "Enemy Kills", "type": TYPE_LIFETIME, "title": "Kill 1,000 enemies", "target": 1000, "reward": 30 },
	{ "id": "ten_thousand", "category": "Enemy Kills", "type": TYPE_LIFETIME, "title": "Kill 10,000 enemies", "target": 10000, "reward": 150 },
	{ "id": "exterminator", "category": "Enemy Kills", "type": TYPE_RUN, "title": "Kill 100 enemies in one run", "target": 100, "reward": 10 },
	{ "id": "unstoppable", "category": "Enemy Kills", "type": TYPE_RUN, "title": "Kill 500 enemies in one run", "target": 500, "reward": 25 },
	{ "id": "crowd_control", "category": "Enemy Kills", "type": TYPE_RUN, "title": "Kill 10 enemies within 1 second", "target": 10, "reward": 20 },
	{ "id": "overkill", "category": "Enemy Kills", "type": TYPE_LIFETIME, "title": "Deal 1,000 damage with a single hit", "target": 1, "reward": 30 },

	# Wave milestones
	{ "id": "first_descent", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Complete wave 1", "target": 1, "reward": 5 },
	{ "id": "descender", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Reach wave 5", "target": 5, "reward": 10 },
	{ "id": "quarter_century", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Reach wave 25", "target": 25, "reward": 40 },
	{ "id": "halfway_to_the_abyss", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Reach wave 50", "target": 50, "reward": 100 },
	{ "id": "the_century", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Reach wave 100", "target": 100, "reward": 250 },
	{ "id": "marathon", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Complete 50 waves in one run", "target": 50, "reward": 100 },
	{ "id": "perfect_wave", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Complete a wave without taking damage", "target": 1, "reward": 10 },
	{ "id": "untouchable", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Complete waves 1-10 without taking damage", "target": 10, "reward": 50 },

	# Survival
	{ "id": "survivor", "category": "Survival", "type": TYPE_RUN, "title": "Survive 10 minutes", "target": 1, "reward": 15 },
	{ "id": "endless", "category": "Survival", "type": TYPE_RUN, "title": "Survive 30 minutes", "target": 1, "reward": 50 },
	{ "id": "last_stand", "category": "Survival", "type": TYPE_RUN, "title": "Survive 10 seconds at 1 HP", "target": 1, "reward": 25 },
	{ "id": "close_call", "category": "Survival", "type": TYPE_RUN, "title": "Complete a wave with exactly 1 HP", "target": 1, "reward": 25 },

	# Bosses
	{ "id": "first_boss", "category": "Bosses", "type": TYPE_LIFETIME, "title": "Kill your first boss", "target": 1, "reward": 10 },
	{ "id": "boss_hunter", "category": "Bosses", "type": TYPE_LIFETIME, "title": "Kill 10 bosses", "target": 10, "reward": 50 },
	{ "id": "boss_slayer", "category": "Bosses", "type": TYPE_LIFETIME, "title": "Kill 25 bosses", "target": 25, "reward": 100 },
	{ "id": "boss_rush", "category": "Bosses", "type": TYPE_RUN, "title": "Kill 3 bosses in one run", "target": 3, "reward": 30 },
	{ "id": "giant_killer", "category": "Bosses", "type": TYPE_RUN, "title": "Kill a boss with a summon", "target": 1, "reward": 20 },
	{ "id": "clean_kill", "category": "Bosses", "type": TYPE_RUN, "title": "Kill a boss without taking damage", "target": 1, "reward": 30 },
	{ "id": "speedrun", "category": "Bosses", "type": TYPE_RUN, "title": "Kill a boss within 10 seconds of it spawning", "target": 1, "reward": 25 },

	# Weapons
	{ "id": "rupture_initiate", "category": "Weapons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Rupture", "target": 100, "reward": 15 },
	{ "id": "rupture_master", "category": "Weapons", "type": TYPE_LIFETIME, "title": "Kill 1,000 enemies with Rupture", "target": 1000, "reward": 60 },
	{ "id": "torcher_initiate", "category": "Weapons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Torcher", "target": 100, "reward": 15 },
	{ "id": "torcher_master", "category": "Weapons", "type": TYPE_LIFETIME, "title": "Kill 1,000 enemies with Torcher", "target": 1000, "reward": 60 },
	{ "id": "dual_threat", "category": "Weapons", "type": TYPE_RUN, "title": "Kill 100 enemies with both weapons in one run", "target": 1, "reward": 30 },
	{ "id": "one_weapon_army", "category": "Weapons", "type": TYPE_RUN, "title": "Reach wave 30 with only one weapon", "target": 30, "reward": 60 },

	# Summons
	{ "id": "first_summon", "category": "Summons", "type": TYPE_LIFETIME, "title": "Obtain your first summon", "target": 1, "reward": 5 },
	{ "id": "summoner", "category": "Summons", "type": TYPE_RUN, "title": "Have 3 summons active at once", "target": 3, "reward": 20 },
	{ "id": "beastmaster", "category": "Summons", "type": TYPE_RUN, "title": "Have 5 summons active at once", "target": 5, "reward": 40 },
	{ "id": "lightning_rod", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Lightning Strike or Hexa Snail", "target": 100, "reward": 15 },
	{ "id": "storm_chaser", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Silver Storm", "target": 100, "reward": 15 },
	{ "id": "return_to_sender", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Recall Dagger", "target": 100, "reward": 15 },
	{ "id": "star_power", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Miniature Star", "target": 100, "reward": 15 },
	{ "id": "focus_fire", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Laser Orb", "target": 100, "reward": 15 },
	{ "id": "event_horizon", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Gravity Bomb", "target": 100, "reward": 15 },
	{ "id": "ring_of_fire", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Fiery Field", "target": 100, "reward": 15 },
	{ "id": "absolute_zero", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Cryolite", "target": 100, "reward": 15 },
	{ "id": "judgment", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 50 enemies with Retribution", "target": 50, "reward": 15 },
	{ "id": "aura_farmer", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 250 enemies with Aura", "target": 250, "reward": 20 },

	# Status effects
	{ "id": "slow_burn", "category": "Status Effects", "type": TYPE_LIFETIME, "title": "Apply burn 100 times", "target": 100, "reward": 10 },
	{ "id": "deep_freeze", "category": "Status Effects", "type": TYPE_LIFETIME, "title": "Freeze 100 enemies", "target": 100, "reward": 15 },
	{ "id": "bleed_them_dry", "category": "Status Effects", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with bleed", "target": 100, "reward": 15 },
	{ "id": "chain_gang", "category": "Status Effects", "type": TYPE_RUN, "title": "Hit 5 enemies with one lightning chain", "target": 5, "reward": 20 },
	{ "id": "shatter", "category": "Status Effects", "type": TYPE_LIFETIME, "title": "Kill 25 frozen enemies", "target": 25, "reward": 15 },
	{ "id": "contagion", "category": "Status Effects", "type": TYPE_RUN, "title": "Spread bleed to 10 enemies with one icicle explosion", "target": 10, "reward": 30 },

	# Build and upgrades
	{ "id": "faster", "category": "Build & Upgrades", "type": TYPE_RUN, "title": "Pick Faster 6 times in one run", "target": 6, "reward": 20 },
	{ "id": "greedy", "category": "Build & Upgrades", "type": TYPE_RUN, "title": "Pick Greed 5 times in one run", "target": 5, "reward": 20 },
	{ "id": "level_25", "category": "Build & Upgrades", "type": TYPE_RUN, "title": "Reach level 25 in one run", "target": 25, "reward": 20 },
	{ "id": "level_50", "category": "Build & Upgrades", "type": TYPE_RUN, "title": "Reach level 50 in one run", "target": 50, "reward": 50 },
	{ "id": "specialized", "category": "Build & Upgrades", "type": TYPE_LIFETIME, "title": "Fully max out one upgrade branch", "target": 1, "reward": 30 },
	{ "id": "the_hard_way", "category": "Build & Upgrades", "type": TYPE_RUN, "title": "Reach wave 20 without picking any summon", "target": 20, "reward": 40 },

	# Echoes and meta progression
	{ "id": "first_return", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Complete your first run", "target": 1, "reward": 5 },
	{ "id": "echo_collector", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Earn 100 Echoes total", "target": 100, "reward": 10 },
	{ "id": "echo_hoarder", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Earn 1,000 Echoes total", "target": 1000, "reward": 50 },
	{ "id": "vault_keeper", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Earn 10,000 Echoes total", "target": 10000, "reward": 200 },
	{ "id": "veteran", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Complete 25 runs", "target": 25, "reward": 50 },
	{ "id": "dedicated", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Complete 100 runs", "target": 100, "reward": 150 },
	{ "id": "deep_pockets", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Hold 1,000 Echoes at once", "target": 1000, "reward": 50 },

	# Secret / challenge
	{ "id": "anomaly", "category": "Challenges", "type": TYPE_RUN, "title": "Kill 50 enemies with the black hole in one run", "target": 50, "reward": 30 },
	{ "id": "chain_reaction", "category": "Challenges", "type": TYPE_RUN, "title": "Kill 10 enemies with one explosion", "target": 10, "reward": 30 },
	{ "id": "frozen_army", "category": "Challenges", "type": TYPE_RUN, "title": "Freeze 10 enemies at once", "target": 10, "reward": 30 },
	{ "id": "no_safety_net", "category": "Challenges", "type": TYPE_RUN, "title": "Reach wave 25 without picking Life or Regen", "target": 25, "reward": 50 },
	{ "id": "the_long_night", "category": "Challenges", "type": TYPE_RUN, "title": "Reach wave 100 without using a revive", "target": 100, "reward": 300 },
	{ "id": "weapon_loyalist", "category": "Challenges", "type": TYPE_LIFETIME, "title": "Kill 25 bosses with the same weapon", "target": 25, "reward": 75 },
]
