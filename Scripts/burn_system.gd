class_name BurnSystem
extends MultiMeshInstance2D

## Every burn of the run, run from this one node (created by world.gd;
## on_run_features.burn_inflict() adds to it). Replaces one Burn node per
## burning enemy, each its own 32-particle GPUParticles2D: with the whole crowd
## on fire, those 200 emitters plus their per-stack ticks cost about 45 ms a
## frame on a desktop. Built like bleed_system.gd.
##
## Logic, unchanged: each burn applied becomes a stack that ticks once a second
## for LIFETIME_TOTAL_BURN ticks (times its duration multiplier, from Lingering
## Flame; a shortened last tick deals that fraction of the damage). Stacks
## applied within MERGE_WINDOW of another stack's tick join its schedule, so
## they tick as one hit and one damage number (the summed damage) instead of a
## pile of overlapping ones. Total damage is the same.
##
## Look, unchanged: FLAMES_PER_SECOND flame particles per burning enemy, spread
## over a FLAME_SPREAD circle, drifting up, spinning, shrinking and turning from
## orange to deep red (burn_flames.gdshader). A particle is just a MultiMesh
## slot written once; the GPU does the rest.

const LIFETIME_TOTAL_BURN: int = 4
const BURN_FREQUENCY: float = 1.0
const MERGE_WINDOW: float = 0.15
const FLAMES_PER_SECOND: float = 32.0
const FLAME_INTERVAL: float = 1.0 / FLAMES_PER_SECOND
const FLAME_LIFETIME: float = 1.0
const FLAME_SPREAD: float = 17.07
const FLAME_SIZE_MIN: float = 2.0
const FLAME_SIZE_MAX: float = 4.0
const FLAME_ANGLE_MIN: float = deg_to_rad(-167.2)
const FLAME_ANGLE_MAX: float = deg_to_rad(136.5)
## Particle slots, reused oldest first. 200 burning enemies x 32 a second x 1 s.
const CAPACITY: int = 7168
## The particle clock wraps every this many seconds (see burn_flames.gdshader).
const CLOCK_WRAP: float = 8.0

var _now: float = 0.0
var _flame_clock: float = 0.0   # _now wrapped to CLOCK_WRAP, for the shader
var _rid: RID
var _next_slot: int = 0
# Particles are spawned into slots in ring order, so they also expire in that
# order: _oldest is the oldest live one, _live how many there are. Expired
# slots are emptied (size 0) so the wrapping clock can never bring one back.
var _oldest: int = 0
var _live: int = 0
var _spawn_time: PackedFloat32Array = PackedFloat32Array()
var _mat: ShaderMaterial
# Burning enemies, and each one's state in its marks["burn"] (other code checks
# marks.has("burn")):
# {"stacks": [[damage per tick, total ticks, ticks done, time of next tick, share of next tick], ...],
#  "emit": seconds, "next": earliest next tick of any stack (skip the stacks until then)}
var _enemies: Array = []


func _init() -> void:
	z_index = 1   # above the enemies, as the old emitters were
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	# Never cull: particles are written straight to the RenderingServer and
	# moved in the shader, so computed bounds would go stale (see
	# bleed_system.gd). Same as ExpDropMMI and the grass.
	multimesh.custom_aabb = AABB(Vector3(-50000, -50000, 0), Vector3(100000, 100000, 1))
	multimesh.instance_count = CAPACITY
	_rid = multimesh.get_rid()
	# Slot 0 starts empty (size 0), so the shader is drawn (and compiled) from
	# the start of the run instead of on the first burn.
	multimesh.set_instance_custom_data(0, Color(0.0, 0.0, 0.0, 0.0))
	# Draw every slot from the start and never change the count: growing the
	# visible instance count while slots are being written crashed the game
	# (signal 11) in the Compatibility renderer. Unused slots are size 0 and
	# draw nothing; the vertex shader collapses them.
	multimesh.visible_instance_count = -1
	_spawn_time.resize(CAPACITY)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://Shaders/burn_flames.gdshader")
	_mat.set_shader_parameter(&"lifetime", FLAME_LIFETIME)
	material = _mat


## Adds a burn stack of `damage` per tick to `enemy`. `durationMultiplier`
## lengthens it (Torcher's Lingering Flame).
func inflict(enemy: Node2D, damage: float, durationMultiplier: float = 1.0) -> void:
	var state = enemy.marks.get("burn")
	if state == null:
		state = {"stacks": [], "emit": randf() * FLAME_INTERVAL, "next": INF}
		enemy.marks["burn"] = state
		_enemies.append(enemy)
	var stacks: Array = state.stacks
	var due: float = _now + BURN_FREQUENCY
	for stack: Array in stacks:
		if absf(stack[3] - due) <= MERGE_WINDOW:
			due = stack[3]
			break
	var lifetimeTicks: float = LIFETIME_TOTAL_BURN * maxf(durationMultiplier, 0.0)
	stacks.append([damage, lifetimeTicks, 0.0, due, 1.0])
	state.next = minf(state.next, due)


func _process(delta: float) -> void:
	_now += delta
	_flame_clock = fmod(_flame_clock + delta, CLOCK_WRAP)
	_mat.set_shader_parameter(&"now", _flame_clock)
	while _live > 0 and _now - _spawn_time[_oldest] > FLAME_LIFETIME:
		RenderingServer.multimesh_instance_set_custom_data(_rid, _oldest, Color(0.0, 0.0, 0.0, 0.0))
		_oldest = (_oldest + 1) % CAPACITY
		_live -= 1
	var i: int = 0
	while i < _enemies.size():
		if _update_enemy(_enemies[i], delta):
			i += 1
		else:
			_enemies[i] = _enemies[_enemies.size() - 1]
			_enemies.pop_back()


## Flames and ticks for one enemy. False once it no longer burns.
func _update_enemy(enemy, delta: float) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy.dead:
		enemy.marks.erase("burn")
		return false
	var state: Dictionary = enemy.marks["burn"]
	var at: Vector2 = enemy.global_position

	var emit: float = state.emit + delta
	while emit >= FLAME_INTERVAL:
		emit -= FLAME_INTERVAL
		_spawn_flame(at)
	state.emit = emit

	if _now < state.next:
		return true   # no stack is due yet
	var stacks: Array = state.stacks
	var damage: float = 0.0
	var next: float = INF
	var k: int = 0
	while k < stacks.size():
		var stack: Array = stacks[k]
		if _now < stack[3]:
			next = minf(next, stack[3])
			k += 1
			continue
		var fraction: float = stack[4]
		damage += stack[0] * fraction
		stack[2] += fraction
		var remaining: float = stack[1] - stack[2]
		if remaining <= 0.001:
			stacks.remove_at(k)
			continue
		stack[4] = minf(remaining, 1.0)
		stack[3] += BURN_FREQUENCY * stack[4]
		next = minf(next, stack[3])
		k += 1
	state.next = next
	if damage > 0.0:
		global.add_damage_text(at, damage, global.DAMAGE_TYPES.INFERNO)
		if AchievementManager.hit(enemy, damage, &"burn") <= 0.0:
			return false   # it died; its marks go with it

	if stacks.is_empty():
		enemy.marks.erase("burn")
		return false
	return true


func _spawn_flame(at: Vector2) -> void:
	var slot: int = _next_slot
	_next_slot = (_next_slot + 1) % CAPACITY
	if _live == CAPACITY:   # full: this overwrites the oldest live particle
		_oldest = (_oldest + 1) % CAPACITY
		_live -= 1
	_live += 1
	_spawn_time[slot] = _now
	var offset := Vector2.from_angle(randf() * TAU) * FLAME_SPREAD * sqrt(randf())
	RenderingServer.multimesh_instance_set_transform_2d(_rid, slot, Transform2D(0.0, at + offset))
	RenderingServer.multimesh_instance_set_custom_data(_rid, slot, Color(randf(), _flame_clock,
		randf_range(FLAME_SIZE_MIN, FLAME_SIZE_MAX), randf_range(FLAME_ANGLE_MIN, FLAME_ANGLE_MAX)))
