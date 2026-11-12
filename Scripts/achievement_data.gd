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
##   stat     - (optional) AchievementManager stat that drives progress. Without it
##              the achievement is not tracked yet and stays at 0.
##   threshold- (optional) for yes/no achievements: complete once stat >= threshold.
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
	{ "id": "first_blood", "category": "Enemy Kills", "type": TYPE_LIFETIME, "title": "Kill 1 enemy", "target": 1, "reward": 5, "stat": "lifetime_kills" },
	{ "id": "century", "category": "Enemy Kills", "type": TYPE_LIFETIME, "title": "Kill 100 enemies", "target": 100, "reward": 10, "stat": "lifetime_kills" },
	{ "id": "thousand_cuts", "category": "Enemy Kills", "type": TYPE_LIFETIME, "title": "Kill 1,000 enemies", "target": 1000, "reward": 30, "stat": "lifetime_kills" },
	{ "id": "ten_thousand", "category": "Enemy Kills", "type": TYPE_LIFETIME, "title": "Kill 10,000 enemies", "target": 10000, "reward": 150, "stat": "lifetime_kills" },
	{ "id": "exterminator", "category": "Enemy Kills", "type": TYPE_RUN, "title": "Kill 100 enemies in one run", "target": 100, "reward": 10, "stat": "best_run_kills" },
	{ "id": "unstoppable", "category": "Enemy Kills", "type": TYPE_RUN, "title": "Kill 500 enemies in one run", "target": 500, "reward": 25, "stat": "best_run_kills" },
	{ "id": "crowd_control", "category": "Enemy Kills", "type": TYPE_RUN, "title": "Kill 10 enemies within 1 second", "target": 10, "reward": 20, "stat": "best_kills_in_one_second" },
	{ "id": "overkill", "category": "Enemy Kills", "type": TYPE_LIFETIME, "title": "Deal 1,000 damage with a single hit", "target": 1, "reward": 30, "stat": "biggest_hit", "threshold": 1000 },

	# Wave milestones
	{ "id": "first_descent", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Complete wave 1", "target": 1, "reward": 5, "stat": "best_run_waves_completed" },
	{ "id": "descender", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Reach wave 5", "target": 5, "reward": 10, "stat": "best_wave_reached" },
	{ "id": "quarter_century", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Reach wave 25", "target": 25, "reward": 40, "stat": "best_wave_reached" },
	{ "id": "halfway_to_the_abyss", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Reach wave 50", "target": 50, "reward": 100, "stat": "best_wave_reached" },
	{ "id": "the_century", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Reach wave 100", "target": 100, "reward": 250, "stat": "best_wave_reached" },
	{ "id": "marathon", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Complete 50 waves in one run", "target": 50, "reward": 100, "stat": "best_run_waves_completed" },
	{ "id": "perfect_wave", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Complete a wave without taking damage", "target": 1, "reward": 10, "stat": "best_run_flawless_waves" },
	{ "id": "untouchable", "category": "Wave Milestones", "type": TYPE_RUN, "title": "Complete waves 1-10 without taking damage", "target": 10, "reward": 50, "stat": "best_flawless_start_streak" },

	# Survival
	{ "id": "survivor", "category": "Survival", "type": TYPE_RUN, "title": "Survive 10 minutes", "target": 1, "reward": 15, "stat": "best_run_seconds", "threshold": 600 },
	{ "id": "endless", "category": "Survival", "type": TYPE_RUN, "title": "Survive 30 minutes", "target": 1, "reward": 50, "stat": "best_run_seconds", "threshold": 1800 },
	{ "id": "last_stand", "category": "Survival", "type": TYPE_RUN, "title": "Survive 10 seconds at 1 HP", "target": 1, "reward": 25, "stat": "best_seconds_at_1hp", "threshold": 10 },
	{ "id": "close_call", "category": "Survival", "type": TYPE_RUN, "title": "Complete a wave with exactly 1 HP", "target": 1, "reward": 25, "stat": "close_call_waves" },

	# Bosses
	{ "id": "first_boss", "category": "Bosses", "type": TYPE_LIFETIME, "title": "Kill your first boss", "target": 1, "reward": 10, "stat": "boss_kills" },
	{ "id": "boss_hunter", "category": "Bosses", "type": TYPE_LIFETIME, "title": "Kill 10 bosses", "target": 10, "reward": 50, "stat": "boss_kills" },
	{ "id": "boss_slayer", "category": "Bosses", "type": TYPE_LIFETIME, "title": "Kill 25 bosses", "target": 25, "reward": 100, "stat": "boss_kills" },
	{ "id": "boss_rush", "category": "Bosses", "type": TYPE_RUN, "title": "Kill 3 bosses in one run", "target": 3, "reward": 30, "stat": "best_run_boss_kills" },
	{ "id": "giant_killer", "category": "Bosses", "type": TYPE_RUN, "title": "Kill a boss with a summon", "target": 1, "reward": 20, "stat": "boss_summon_kills" },
	{ "id": "clean_kill", "category": "Bosses", "type": TYPE_RUN, "title": "Kill a boss without taking damage", "target": 1, "reward": 30, "stat": "boss_clean_kills" },
	{ "id": "speedrun", "category": "Bosses", "type": TYPE_RUN, "title": "Kill a boss within 10 seconds of it spawning", "target": 1, "reward": 25, "stat": "boss_speed_kills" },

	# Weapons
	{ "id": "rupture_initiate", "category": "Weapons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Rupture", "target": 100, "reward": 15, "stat": "kills_rupture" },
	{ "id": "rupture_master", "category": "Weapons", "type": TYPE_LIFETIME, "title": "Kill 1,000 enemies with Rupture", "target": 1000, "reward": 60, "stat": "kills_rupture" },
	{ "id": "torcher_initiate", "category": "Weapons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Torcher", "target": 100, "reward": 15, "stat": "kills_torcher" },
	{ "id": "torcher_master", "category": "Weapons", "type": TYPE_LIFETIME, "title": "Kill 1,000 enemies with Torcher", "target": 1000, "reward": 60, "stat": "kills_torcher" },
	{ "id": "dual_threat", "category": "Weapons", "type": TYPE_RUN, "title": "Kill 100 enemies with both weapons in one run", "target": 100, "reward": 30, "stat": "best_run_dual_weapon_kills" },
	{ "id": "one_weapon_army", "category": "Weapons", "type": TYPE_RUN, "title": "Reach wave 30 with only one weapon", "target": 30, "reward": 60, "stat": "best_wave_one_weapon" },

	# Summons
	{ "id": "first_summon", "category": "Summons", "type": TYPE_LIFETIME, "title": "Obtain your first summon", "target": 1, "reward": 5, "stat": "summons_obtained" },
	{ "id": "summoner", "category": "Summons", "type": TYPE_RUN, "title": "Have 3 summons active at once", "target": 3, "reward": 20, "stat": "best_run_summons" },
	{ "id": "beastmaster", "category": "Summons", "type": TYPE_RUN, "title": "Have 5 summons active at once", "target": 5, "reward": 40, "stat": "best_run_summons" },
	{ "id": "lightning_rod", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Lightning Strike or Hexa Snail", "target": 100, "reward": 15, "stat": "kills_lightning" },
	{ "id": "storm_chaser", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Silver Storm", "target": 100, "reward": 15, "stat": "kills_silver_storm" },
	{ "id": "return_to_sender", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Recall Dagger", "target": 100, "reward": 15, "stat": "kills_recall_dagger" },
	{ "id": "star_power", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Miniature Star", "target": 100, "reward": 15, "stat": "kills_star" },
	{ "id": "focus_fire", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Laser Orb", "target": 100, "reward": 15, "stat": "kills_laser_orb" },
	{ "id": "event_horizon", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Gravity Bomb", "target": 100, "reward": 15, "stat": "kills_gravity_bomb" },
	{ "id": "ring_of_fire", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Fiery Field", "target": 100, "reward": 15, "stat": "kills_fiery_field" },
	{ "id": "absolute_zero", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with Cryolite", "target": 100, "reward": 15, "stat": "kills_cryolite" },
	{ "id": "judgment", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 50 enemies with Retribution", "target": 50, "reward": 15, "stat": "kills_retribution" },
	{ "id": "aura_farmer", "category": "Summons", "type": TYPE_LIFETIME, "title": "Kill 250 enemies with Aura", "target": 250, "reward": 20, "stat": "kills_aura" },

	# Status effects
	{ "id": "slow_burn", "category": "Status Effects", "type": TYPE_LIFETIME, "title": "Apply burn 100 times", "target": 100, "reward": 10, "stat": "burns_applied" },
	{ "id": "deep_freeze", "category": "Status Effects", "type": TYPE_LIFETIME, "title": "Freeze 100 enemies", "target": 100, "reward": 15, "stat": "freezes_applied" },
	{ "id": "bleed_them_dry", "category": "Status Effects", "type": TYPE_LIFETIME, "title": "Kill 100 enemies with bleed", "target": 100, "reward": 15, "stat": "kills_bleed" },
	{ "id": "chain_gang", "category": "Status Effects", "type": TYPE_RUN, "title": "Hit 5 enemies with one lightning chain", "target": 5, "reward": 20, "stat": "best_lightning_chain_hits" },
	{ "id": "shatter", "category": "Status Effects", "type": TYPE_LIFETIME, "title": "Kill 25 frozen enemies", "target": 25, "reward": 15, "stat": "frozen_kills" },
	{ "id": "contagion", "category": "Status Effects", "type": TYPE_RUN, "title": "Spread bleed to 10 enemies with one icicle explosion", "target": 10, "reward": 30, "stat": "best_icicle_explosion_spread" },

	# Build and upgrades
	{ "id": "faster", "category": "Build & Upgrades", "type": TYPE_RUN, "title": "Pick Faster 6 times in one run", "target": 6, "reward": 20, "stat": "best_run_faster_picks" },
	{ "id": "greedy", "category": "Build & Upgrades", "type": TYPE_RUN, "title": "Pick Greed 5 times in one run", "target": 5, "reward": 20, "stat": "best_run_greed_picks" },
	{ "id": "level_25", "category": "Build & Upgrades", "type": TYPE_RUN, "title": "Reach level 25 in one run", "target": 25, "reward": 20, "stat": "best_run_level" },
	{ "id": "level_50", "category": "Build & Upgrades", "type": TYPE_RUN, "title": "Reach level 50 in one run", "target": 50, "reward": 50, "stat": "best_run_level" },
	{ "id": "specialized", "category": "Build & Upgrades", "type": TYPE_LIFETIME, "title": "Fully max out one upgrade branch", "target": 1, "reward": 30, "stat": "maxed_branches" },
	{ "id": "the_hard_way", "category": "Build & Upgrades", "type": TYPE_RUN, "title": "Reach wave 20 without picking any summon", "target": 20, "reward": 40, "stat": "best_wave_no_summon" },

	# Echoes and meta progression
	{ "id": "first_return", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Complete your first run", "target": 1, "reward": 5, "stat": "runs_completed" },
	{ "id": "echo_collector", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Earn 100 Echoes total", "target": 100, "reward": 10, "stat": "echoes_earned" },
	{ "id": "echo_hoarder", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Earn 1,000 Echoes total", "target": 1000, "reward": 50, "stat": "echoes_earned" },
	{ "id": "vault_keeper", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Earn 10,000 Echoes total", "target": 10000, "reward": 200, "stat": "echoes_earned" },
	{ "id": "veteran", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Complete 25 runs", "target": 25, "reward": 50, "stat": "runs_completed" },
	{ "id": "dedicated", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Complete 100 runs", "target": 100, "reward": 150, "stat": "runs_completed" },
	{ "id": "deep_pockets", "category": "Echoes & Meta Progression", "type": TYPE_LIFETIME, "title": "Hold 1,000 Echoes at once", "target": 1000, "reward": 50, "stat": "most_echoes_held" },

	# Secret / challenge
	{ "id": "anomaly", "category": "Challenges", "type": TYPE_RUN, "title": "Kill 50 enemies with the black hole in one run", "target": 50, "reward": 30, "stat": "best_run_black_hole_kills" },
	{ "id": "chain_reaction", "category": "Challenges", "type": TYPE_RUN, "title": "Kill 10 enemies with one explosion", "target": 10, "reward": 30, "stat": "best_explosion_kills" },
	{ "id": "frozen_army", "category": "Challenges", "type": TYPE_RUN, "title": "Freeze 10 enemies at once", "target": 10, "reward": 30, "stat": "best_frozen_at_once" },
	{ "id": "no_safety_net", "category": "Challenges", "type": TYPE_RUN, "title": "Reach wave 25 without picking Life or Regen", "target": 25, "reward": 50, "stat": "best_wave_no_life_regen" },
	{ "id": "the_long_night", "category": "Challenges", "type": TYPE_RUN, "title": "Reach wave 100 without using a revive", "target": 100, "reward": 300, "stat": "best_wave_no_revive" },
	{ "id": "weapon_loyalist", "category": "Challenges", "type": TYPE_LIFETIME, "title": "Kill 25 bosses with the same weapon", "target": 25, "reward": 75, "stat": "best_weapon_boss_kills" },
]
