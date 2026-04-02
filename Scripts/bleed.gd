class_name Bleed
extends GPUParticles2D

const LIFETIME_TOTAL_BLEED: int = 4
const BLEED_FREQUENCY: float = 1.0
var parent: CharacterBody2D = null
var bleedDamage: float = 3.0
var bleededCount: int = 0
var m: Dictionary = {}
@onready var damageType: int = global.DAMAGE_TYPES.PHYSICAL


func set_damage(damage: float) -> void:
	bleedDamage = damage


func hit() -> void:
	parent.get_hit(bleedDamage)
	global.add_damage_text(global_position, bleedDamage, damageType)
	bleededCount += 1
	
	if bleededCount == LIFETIME_TOTAL_BLEED:
		queue_free()
		return
	get_tree().create_timer(BLEED_FREQUENCY).timeout.connect(hit)


func _ready() -> void:
	parent = get_parent()
	z_index = 1
	get_tree().create_timer(BLEED_FREQUENCY).timeout.connect(hit)
	
	m = parent.marks
	if m.has('bleed'):
		m['bleed'] += 1
		return
	m['bleed'] = 1


func _exit_tree() -> void:
	m["bleed"] -= 1
	if m["bleed"] == 0:
		m.erase('bleed')
