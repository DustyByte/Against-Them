class_name EnemyStats

var hp: float = 40
var damage: float = 10
## Full health (hp counts down from it); the black hole's boss finisher reads it.
var maxHp: float = 40

func _init(characterBaseStats: Dictionary) -> void:
	hp = characterBaseStats.hp
	maxHp = hp
	damage = characterBaseStats.damage


func apply_multipliers(hp_multiplier: float, damage_multiplier: float) -> void:
	hp *= hp_multiplier
	maxHp *= hp_multiplier
	damage *= damage_multiplier
