class_name PlayerStats

const BASE_HP: float = 300
var maxHP: float = BASE_HP
var currentHP: float = BASE_HP
var currentExp: float = 0


var activeModifiers: Dictionary = {
	L_StrikeOnShoot = true, # remove all these later.
	L_StrikeDamage = 20,
	L_StrikeAfterAmmo = 1,
	L_StrikeAmount = 2
}


## Adds given exp amount and returns the current exp.
func add_exp(expAmount: float) -> float:
	currentExp += expAmount
	return currentExp


## Adds the given modifier to stats accordingly. Used for modifiers from items and jewels.
func add_modifiers(modifiers: Dictionary) -> void:
	for key in modifiers:
		var value = modifiers[key]
		if key in activeModifiers:
			activeModifiers[key] = activeModifiers[key]+value if _should_be_added(key) else activeModifiers[key]*value
		else:
			activeModifiers[key] = value


func _should_be_added(key: String) -> bool:
	return global.ACTION_TO_PERFORM_TO_AUGMENT[key] == "added"


func _get_calculated_hp() -> float:
	var hp: float
	for key in activeModifiers:
		pass # perform math to get current hp here
	return hp


func update_max_hp() -> float:
	pass # perfom math to update maxHP here
	return maxHP
