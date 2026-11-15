class_name Burn
extends GPUParticles2D

## The burn on one enemy. Every burn applied to that enemy becomes a stack here,
## ticking once a second for LIFETIME_TOTAL_BURN ticks (longer with Lingering
## Flame), all sharing this one particle emitter. Before, every burn added its
## own emitter and timers, so stacked burns on many enemies meant hundreds of
## particle systems. Stored as the enemy's marks["burn"] so
## on_run_features.burn_inflict() can add to it.

const LIFETIME_TOTAL_BURN: int = 4
const BURN_FREQUENCY: float = 1.0
var parent: CharacterBody2D = null
var damageType: int = global.DAMAGE_TYPES.INFERNO
var _time: float = 0.0
# One per stack: [damage per tick, total ticks, ticks done, time of next tick, share of next tick]
var _stacks: Array[Array] = []


## `durationMultiplier` lengthens the burn; a shortened last tick deals that
## fraction of the damage.
func add_stack(damage: float, durationMultiplier: float = 1.0) -> void:
	var lifetimeTicks: float = LIFETIME_TOTAL_BURN * maxf(durationMultiplier, 0.0)
	_stacks.append([damage, lifetimeTicks, 0.0, _time + BURN_FREQUENCY, 1.0])


func _ready() -> void:
	parent = get_parent()
	z_index = 1
	parent.marks["burn"] = self


func _exit_tree() -> void:
	if parent.marks.get("burn") == self:
		parent.marks.erase("burn")


func _process(delta: float) -> void:
	_time += delta
	var i: int = 0
	while i < _stacks.size():
		var stack: Array = _stacks[i]
		if _time < stack[3]:
			i += 1
			continue

		var fraction: float = stack[4]
		var damage: float = stack[0] * fraction
		var remainingHP: float = AchievementManager.hit(parent, damage, &"burn")
		global.add_damage_text(global_position, damage, damageType)
		if remainingHP <= 0.0:
			set_process(false)   # the enemy died; it is freed with this burn
			return

		stack[2] += fraction
		var remaining: float = stack[1] - stack[2]
		if remaining <= 0.001:
			_stacks.remove_at(i)
			continue
		stack[4] = minf(remaining, 1.0)
		stack[3] += BURN_FREQUENCY * stack[4]
		i += 1

	if _stacks.is_empty():
		queue_free()
