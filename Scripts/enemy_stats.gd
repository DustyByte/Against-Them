class_name EnemyStats

var hp: float = 40
var damage: float = 10

func _init(characterBaseStats: Dictionary) -> void:
	hp = characterBaseStats.hp
	damage = characterBaseStats.damage


func apply_multipliers(hp_multiplier: float, damage_multiplier: float) -> void:
	hp *= hp_multiplier
	damage *= damage_multiplier
