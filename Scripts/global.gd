extends Node

const GAME_VERSION: String = "2.1.0"

enum DAMAGE_TYPES {
	PHYSICAL,
	ELECTRO,
	FROST,
	INFERNO,
	EXOTIC,
	PLAYER_HIT,
	PLAYER_HEAL
}
const DAMAGE_TYPE_COLORS: Array[Color] = [Color.CRIMSON, Color.MEDIUM_AQUAMARINE, Color.POWDER_BLUE, Color.LIGHT_CORAL, Color.MEDIUM_ORCHID, Color.RED, Color.GREEN]
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
	BURN_EMISSION = preload("res://Scenes/Effects/burn_emission.tscn"),
	FREEZE = preload("res://Scenes/Effects/freeze.tscn"),
	BLEED = preload("res://Scenes/Effects/bleed.tscn")
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
const ENEMY_SPEED_MULTIPLIER: float = 2.06

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
