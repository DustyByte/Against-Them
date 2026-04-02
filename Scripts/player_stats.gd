class_name PlayerStats

const BASE_HP: float = 3000
var maxHP: float = BASE_HP
var currentHP: float = BASE_HP
var currentExp: float = 0.0


var activeModifiers: Dictionary = {
	maxHPMultiplier = 1.0,
	maxHPIncrease = 0.0,
}


## Adds the given EXP and returns the current EXP.
func add_exp(amount: float) -> float:
	currentExp += amount
	return currentExp


## Adds the given modifier to stats accordingly. Used for modifiers from items and jewels.
func add_modifiers(modifiers: Dictionary) -> void:
	for key in modifiers:
		var value = modifiers[key]
		if key in activeModifiers:
			activeModifiers[key] = activeModifiers[key]+value if _should_be_added(key) else activeModifiers[key]*value
		else:
			activeModifiers[key] = value


## Adds the given amount to max HP and increaes current HP accordingly.
func increase_max_hp(amount: float) -> void:
	activeModifiers.maxHPIncrease += amount
	update_max_hp()
	currentHP += amount
	print(maxHP)


func _should_be_added(key: String) -> bool:
	return global.ACTION_TO_PERFORM_TO_AUGMENT[key] == "added"


func _get_calculated_hp() -> float:
	var hp: float
	for key in activeModifiers:
		pass # perform math to get current hp here
	return hp


func update_max_hp() -> float:
	maxHP = BASE_HP*activeModifiers.maxHPMultiplier + activeModifiers.maxHPIncrease
	return maxHP
