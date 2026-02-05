extends Node

const EXP_DROP_TYPES: Dictionary = {
	TYPE_1 = {
		expAmount = 1,
		color = Color.DARK_SEA_GREEN
	},
	TYPE_2 = {
		expAmount = 10,
		color = Color.DARK_SLATE_BLUE
	},
	TYPE_3 = {
		expAmount = 100,
		color = Color.DARK_ORCHID
	}
}

const ENEMY_BASE_STATS: Dictionary = {
	"Type_1" : {
		hp = 40,
		damage = 10
	}
}

const ACTION_TO_PERFORM_TO_AUGMENT: Dictionary = {
	
}

const SHAKE_AMOUNTS: Dictionary = {
	LIGHTNING_STRIKE = 7
}

const FREQUENT_EFFECTS_BLUEPRINTS: Dictionary = {
	LIGHTNING_BLUEPRINT = preload("res://Scenes/lightning.tscn")
}

var PLAYER: CharacterBody2D = null
var WORLD: Node2D = null
const EXP_DROP_SIZE: float = 10.0
var activeCamera: Camera2D = null
