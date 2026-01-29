class_name EnemyStats

var hp: float = 40
var damage: float = 10

func _init(characterBaseStats: Dictionary) -> void:
	hp = characterBaseStats.hp
	damage = characterBaseStats.damage
