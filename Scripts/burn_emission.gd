class_name Burn
extends GPUParticles2D

const LIFETIME_TOTAL_BURN: int = 4
const BURN_FREQUENCY: float = 1.0
var parent: CharacterBody2D = null
var burnDamage: float = 3.0
var burnedCount: int = 0
var m: Dictionary = {}
@onready var damageType: int = global.DAMAGE_TYPES.INFERNO


func set_damage(damage: float) -> void:
	burnDamage = damage


func hit() -> void:
	AchievementManager.hit(parent, burnDamage, &"burn")
	global.add_damage_text(global_position, burnDamage, damageType)
	burnedCount += 1
	
	if burnedCount == LIFETIME_TOTAL_BURN:
		queue_free()
		return
	get_tree().create_timer(BURN_FREQUENCY).timeout.connect(hit)


func _ready() -> void:
	parent = get_parent()
	z_index = 1
	get_tree().create_timer(BURN_FREQUENCY).timeout.connect(hit)
	
	m = parent.marks
	if m.has('burn'):
		m['burn'] += 1
		return
	m['burn'] = 1


func _exit_tree() -> void:
	m["burn"] -= 1
	if m["burn"] == 0:
		m.erase('burn')
