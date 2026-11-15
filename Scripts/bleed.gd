class_name Bleed
extends GPUParticles2D

## The bleed on one enemy. Every bleed applied to that enemy becomes a stack
## here, ticking once a second for LIFETIME_TOTAL_BLEED ticks, all sharing this
## one particle emitter (before, every bleed added its own emitter and timers).
## Stored as the enemy's marks["bleed"] so on_run_features.bleed_inflict() can
## add to it.

const LIFETIME_TOTAL_BLEED: int = 4
const BLEED_FREQUENCY: float = 1.0
var parent: CharacterBody2D = null
var damageType: int = global.DAMAGE_TYPES.PHYSICAL
var _time: float = 0.0
# One per stack: [damage per tick, ticks done, time of next tick]
var _stacks: Array[Array] = []


func add_stack(damage: float) -> void:
	_stacks.append([damage, 0, _time + BLEED_FREQUENCY])


func _ready() -> void:
	parent = get_parent()
	z_index = 1
	parent.marks["bleed"] = self


func _exit_tree() -> void:
	if parent.marks.get("bleed") == self:
		parent.marks.erase("bleed")


func _process(delta: float) -> void:
	_time += delta
	var i: int = 0
	while i < _stacks.size():
		var stack: Array = _stacks[i]
		if _time < stack[2]:
			i += 1
			continue

		var damage: float = stack[0]
		var remainingHP: float = AchievementManager.hit(parent, damage, &"bleed")
		global.add_damage_text(global_position, damage, damageType)
		if remainingHP <= 0.0:
			set_process(false)   # the enemy died; it is freed with this bleed
			return

		stack[1] += 1
		if stack[1] >= LIFETIME_TOTAL_BLEED:
			_stacks.remove_at(i)
			continue
		stack[2] += BLEED_FREQUENCY
		i += 1

	if _stacks.is_empty():
		queue_free()
