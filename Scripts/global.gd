extends Node

const GAME_VERSION: String = "2.2.0"

enum DAMAGE_TYPES {
	PHYSICAL,
	ELECTRO,
	FROST,
	INFERNO,
	EXOTIC,
	PLAYER_HIT,
	PLAYER_HEAL
}
## Damage number colours, by DAMAGE_TYPES. Bright, and kept off the blues and
## teals of the ground and enemies (damage_numbers.gd adds a dark outline too).
const DAMAGE_TYPE_COLORS: Array[Color] = [
	Color(1.0, 0.36, 0.32),    # PHYSICAL: bright red (was crimson, too dark on the ground)
	Color(1.0, 0.9, 0.35),     # ELECTRO: lightning yellow (was aquamarine, lost on teal enemies)
	Color(0.8, 0.95, 1.0),     # FROST: icy white-blue
	Color(1.0, 0.6, 0.2),      # INFERNO: orange
	Color(0.95, 0.5, 1.0),     # EXOTIC: bright violet
	Color(1.0, 0.2, 0.25),     # PLAYER_HIT
	Color(0.45, 1.0, 0.45),    # PLAYER_HEAL
]
const EXP_DROP_TYPES: Dictionary = {
	TYPE_1 = {
		expAmount = 1,
		color = Color.DARK_SEA_GREEN
	},
	TYPE_2 = {
		expAmount = 10,
		color = Color(0.5, 0.62, 1.0)   # bright periwinkle; DARK_SLATE_BLUE vanished on the dark ground
	},
	TYPE_3 = {
		expAmount = 100,
		color = Color.CRIMSON
	}
}

const ENEMY_BOSS_BASE_STATS: Dictionary = {
	Type_1 = {
		hp = 2000.0,
		damage = 30.0
	},
	Type_4 = {
		hp = 3000.0,
		damage = 45.0
	}
}

const ENEMY_BASE_STATS: Dictionary = {
	Type_1 = {
		hp = 40.0,
		damage = 10.0
	},
	Type_4 = {
		hp = 60.0,
		damage = 15.0
	},
	Type_6 = {
		hp = 30.0,
		damage = 30.0
	}
}
const ENEMY_BPS: Dictionary = {
	Type_1 = preload("res://Scenes/Enemies/enemy_1.tscn"),
	Type_4 = preload("res://Scenes/Enemies/enemy_4.tscn"),
	Type_6 = preload("res://Scenes/Enemies/enemy_6.tscn")
}
const ACTION_TO_PERFORM_TO_AUGMENT: Dictionary = {
	
}
const SHAKE_AMOUNTS: Dictionary = {
	LIGHTNING_STRIKE = 7
}
const FREQUENT_EFFECTS_BLUEPRINTS: Dictionary = {
	LIGHTNING_BLUEPRINT = preload("res://Scenes/Effects/lightning.tscn"),
	FREEZE = preload("res://Scenes/Effects/freeze.tscn"),
}
var WEAPON_STATS: Dictionary = {
	RUPTURE = {
		damage = 20.0,
		knockBackIntensity = 50.0,
		cd = 0.25,
		reloadTime = 3.0,
		maxAmmo = 7,
		damageType = DAMAGE_TYPES.PHYSICAL
	},
	TORCHER = {
		damage = 6.0,
		knockBackIntensity = 120.0,
		cd = 0.4,
		reloadTime = 2.0,
		maxAmmo = 11,
		damageType = DAMAGE_TYPES.INFERNO
	}
}
var SFX_TYPES_PERM: Dictionary = {
	"ui" : true,
	"game_world" : true
}

var IS_HEPTIC_FEEDBACK_PERMITTED: bool = true
const DEATH_CORRODE_SHADER_MATERIAL: ShaderMaterial = preload("res://Shaders/Material/enemy_death_corrode.tres")
const FREEZE_SHADER_MATERIAL: ShaderMaterial = preload("res://Shaders/Material/freeze_shader_mat.tres")
const ON_RUN_FEATURES: Script = preload("res://Scripts/on_run_features.gd")
const ENEMY_DEATH_STREAM_01: AudioStream = preload("res://Assets/SFX/EnemyDying01.wav")
const ENEMY_DEATH_STREAM_02: AudioStream = preload("res://Assets/SFX/EnemyDying02.wav")
const ENEMY_DEATH_STREAM_03: AudioStream = preload("res://Assets/SFX/GranularExplosion.wav")

var ON_RUN_WEAPON_HANGER: VBoxContainer = null
var FEATURE_AND_SUMMON_MANAGEMENT_SYSTEM: Node = null
var PLAYER: Player = null
var PLAYERS_WEAPON_SYSTEM: Node2D = null
var WORLD: Node2D = null
var ON_RUN_HUD: Control = null
var PROGRESSION_CHOICE_SYSTEM: Node = null
var DETECTOR: BodyDetect = null
var activeCamera: Camera2D = null
var WAVE_MANAGER: Node = null
var TOTAL_ENEMY_KILLS: int = 0
## Revives used this run (shard or ad); capped by MAX_REVIVES_PER_RUN.
var RUN_REVIVES: int = 0
const MAX_REVIVES_PER_RUN: int = 2
## Scales every enemy's chase speed (their speeds relative to each other stay
## the same). At 2.08, enemy 1 runs about 312 px/s: barely faster than Echo's
## 300, so it creeps up on a fleeing player; with a few ranks of Swiftness
## (2% each) Echo can outrun it.
const ENEMY_SPEED_MULTIPLIER: float = 1.5

const DAMAGE_TEXT_OFFSET: Vector2 = Vector2(40.0, -40.0)
func add_damage_text(globalPosEnemy: Vector2, damage: float, damageType: int, isCrit: bool = false) -> void:
	WORLD.damageNumbers.add(globalPosEnemy + DAMAGE_TEXT_OFFSET, damage, damageType, isCrit)


func freeze_world(duration: float):
	Engine.time_scale = 0.0 
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func vibrate_handheld(duration_ms: int, amplitude: float) -> void:
	if IS_HEPTIC_FEEDBACK_PERMITTED:
		Input.vibrate_handheld(duration_ms, amplitude)


func _ready() -> void:
	# Initialize AdMob for rewarded ads
	if OS.get_name() in ["Android", "iOS"]:
		AdMobManager.initialize()
