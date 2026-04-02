extends Area2D


signal levelUp

const ATTRACTING_SPEED: float = 600.0
const BASE_LEVEL_EXP_REQUIREMENT: float = 7000000000.0
const LEVEL_EXP_REQUIREMENT_GROWTH: float = 1.5

@onready var player: CharacterBody2D = $".."
@onready var expBar: ProgressBar = global.ON_RUN_HUD.expBar
@onready var playerStats: PlayerStats = player.stats
var expDropsBeingPickedUp: Array[Area2D] = []
var currentLevel: int = 1
var currentExpMilestone: float = 0.0


func pick_up(expDrop: Area2D) -> void:
	expDropsBeingPickedUp.append(expDrop)
	expDrop.handle_mm_to_cpu_migration()


func _on_area_entered(area: Area2D) -> void:
	if not area.isPickedUp:
		pick_up(area)
		area.isPickedUp = true


func revaluate_exp_barand_milestone() -> void:
	currentExpMilestone = currentLevel * BASE_LEVEL_EXP_REQUIREMENT * LEVEL_EXP_REQUIREMENT_GROWTH
	expBar.max_value = currentExpMilestone
	expBar.value = 0.0


func _ready() -> void:
	revaluate_exp_barand_milestone()


func _process(delta: float) -> void:
	if expDropsBeingPickedUp.is_empty():
		return
	
	for i in range(expDropsBeingPickedUp.size() - 1, -1, -1):
		var expDrop: Area2D = expDropsBeingPickedUp[i]
		
		if expDrop.global_position.distance_squared_to(global_position) <= 400:
			var currentExp: float = playerStats.add_exp(expDrop.expAmount)
			expBar.value += expDrop.expAmount
			
			if currentExp >= currentExpMilestone:
				currentLevel += 1
				playerStats.add_exp(-currentExp)
				levelUp.emit()
				revaluate_exp_barand_milestone()
			
			expDrop.queue_free()
			expDropsBeingPickedUp.remove_at(i)
		
		else:
			var flyDirection: Vector2 = expDrop.global_position.direction_to(global_position)
			expDrop.global_position += flyDirection * ATTRACTING_SPEED * delta
