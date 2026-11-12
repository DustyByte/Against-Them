class_name Aura
extends Area2D

const DAMAGE_TYPE: int = global.DAMAGE_TYPES.EXOTIC
@onready var timer: Timer = $Timer
@onready var collShape: Shape2D = $CollisionShape2D.shape
var stats: Dictionary = {}


func setup(auraStats: Dictionary) -> void:
	stats = auraStats


func hitand_restart_timer() -> void:
	var enemiesInRange: Array[Node2D] = get_overlapping_bodies()
	var d: float = stats.damage
	var killMilestoneMult: int = stats.killMilestoneMult
	var killCount: int = 0
	
	for body in enemiesInRange:
		var remHP: float = AchievementManager.hit(body, d, &"aura")
		if killMilestoneMult and remHP <= 0.0:
			killCount += 1
		global.add_damage_text(body.global_position, d, DAMAGE_TYPE)
	
	if killMilestoneMult:
		stats.killCount += killCount
		if stats.killCount >= 250:
			stats.killCount -= 250
			stats.damage += killMilestoneMult
	
	collShape.radius = stats.range
	timer.start(stats.cd)


func _ready() -> void:
	timer.timeout.connect(hitand_restart_timer)
	timer.start(stats.cd)
