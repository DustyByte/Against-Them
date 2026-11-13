class_name Burn
extends GPUParticles2D

const LIFETIME_TOTAL_BURN: int = 4
const BURN_FREQUENCY: float = 1.0
var parent: CharacterBody2D = null
var burnDamage: float = 3.0
var burnedCount: int = 0
## Ticks the burn lasts (one per second). Can be fractional when the duration
## is extended: the last tick then deals that fraction of the damage.
var lifetimeTicks: float = LIFETIME_TOTAL_BURN
var elapsedTicks: float = 0.0
var m: Dictionary = {}
@onready var damageType: int = global.DAMAGE_TYPES.INFERNO


func set_damage(damage: float) -> void:
	burnDamage = damage


func set_duration_multiplier(multiplier: float) -> void:
	lifetimeTicks = LIFETIME_TOTAL_BURN * maxf(multiplier, 0.0)


## `fraction` < 1 only for a shortened final tick.
func hit(fraction: float = 1.0) -> void:
	var damage: float = burnDamage * fraction
	AchievementManager.hit(parent, damage, &"burn")
	global.add_damage_text(global_position, damage, damageType)
	burnedCount += 1
	elapsedTicks += fraction
	
	var remaining: float = lifetimeTicks - elapsedTicks
	if remaining <= 0.001:
		queue_free()
		return
	var nextFraction: float = minf(remaining, 1.0)
	get_tree().create_timer(BURN_FREQUENCY * nextFraction).timeout.connect(hit.bind(nextFraction))


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
