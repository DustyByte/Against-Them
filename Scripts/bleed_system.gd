class_name BleedSystem
extends MultiMeshInstance2D

## Every bleed of the run, run from this one node (created by world.gd;
## on_run_features.bleed_inflict() adds to it). Replaces one Bleed node per
## bleeding enemy, each its own GPUParticles2D: with 20 Recall Daggers nearly
## every enemy bleeds, and those ~200 emitters plus their per-stack ticks cost
## about 13 ms a frame on a desktop.
##
## Logic, unchanged: each bleed applied becomes a stack that ticks once a
## second, LIFETIME_TOTAL_BLEED times. Stacks applied within MERGE_WINDOW of
## another stack's tick join its schedule, so a volley of daggers ticks as one
## hit and one damage number (the summed damage) instead of a dozen overlapping
## ones. Total damage is the same.
##
## Look, unchanged: DROPS_PER_SECOND red drops per bleeding enemy, spread over
## a DROP_SPREAD circle, moving with the enemy and falling (bleed_drops.gdshader).
## A drop is just a MultiMesh slot written once; the GPU moves and fades it.

const LIFETIME_TOTAL_BLEED: int = 4
const BLEED_FREQUENCY: float = 1.0
const MERGE_WINDOW: float = 0.15
const DROPS_PER_SECOND: float = 11.0
const DROP_INTERVAL: float = 1.0 / DROPS_PER_SECOND
const DROP_LIFETIME: float = 1.0
const DROP_SPREAD: float = 16.0
const DROP_SIZE_MIN: float = 2.0
const DROP_SIZE_MAX: float = 4.0
const DROP_COLOR := Color(1.0, 0.12, 0.12, 1.0)
## Drop slots, reused oldest first. 200 bleeding enemies x 11 drops/s x 1 s.
const CAPACITY: int = 2560
## The drop clock wraps every this many seconds (see bleed_drops.gdshader).
const CLOCK_WRAP: float = 8.0

var _now: float = 0.0
var _drop_clock: float = 0.0   # _now wrapped to CLOCK_WRAP, for the shader
var _rid: RID
var _next_slot: int = 0
var _used: int = 1
# Drops are spawned into slots in ring order, so they also expire in that
# order: _oldest is the oldest live drop, _live how many there are. Expired
# slots are emptied (size 0) so the wrapping clock can never bring one back.
var _oldest: int = 0
var _live: int = 0
var _spawn_time: PackedFloat32Array = PackedFloat32Array()
var _mat: ShaderMaterial
# Bleeding enemies, and each one's state in its marks["bleed"]:
# {"stacks": [[damage per tick, ticks done, time of next tick], ...], "emit": seconds}
var _enemies: Array = []


func _init() -> void:
	z_index = 1   # above the enemies, as the old emitters were
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	# Never cull: drops are written straight to the RenderingServer and moved in
	# the shader, so the computed bounds go stale (they stayed around the world
	# origin, hiding drops elsewhere). Same as ExpDropMMI and the grass.
	multimesh.custom_aabb = AABB(Vector3(-50000, -50000, 0), Vector3(100000, 100000, 1))
	multimesh.instance_count = CAPACITY
	_rid = multimesh.get_rid()
	# Slot 0 starts as an empty drop (size 0), so the shader is drawn (and
	# compiled) from the start of the run instead of on the first bleed.
	multimesh.set_instance_custom_data(0, Color(0.0, 0.0, 0.0, 0.0))
	multimesh.visible_instance_count = _used
	_spawn_time.resize(CAPACITY)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://Shaders/bleed_drops.gdshader")
	_mat.set_shader_parameter(&"lifetime", DROP_LIFETIME)
	material = _mat


## Adds a bleed stack of `damage` per tick to `enemy`.
func inflict(enemy: Node2D, damage: float) -> void:
	var state = enemy.marks.get("bleed")
	if state == null:
		state = {"stacks": [], "emit": randf() * DROP_INTERVAL}
		enemy.marks["bleed"] = state
		_enemies.append(enemy)
	var stacks: Array = state.stacks
	var due: float = _now + BLEED_FREQUENCY
	for stack: Array in stacks:
		if absf(stack[2] - due) <= MERGE_WINDOW:
			due = stack[2]
			break
	stacks.append([damage, 0, due])


func _process(delta: float) -> void:
	_now += delta
	_drop_clock = fmod(_drop_clock + delta, CLOCK_WRAP)
	_mat.set_shader_parameter(&"now", _drop_clock)
	while _live > 0 and _now - _spawn_time[_oldest] > DROP_LIFETIME:
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


## Drops and ticks for one enemy. False once it no longer bleeds.
func _update_enemy(enemy, delta: float) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy.dead:
		enemy.marks.erase("bleed")
		return false
	var state: Dictionary = enemy.marks["bleed"]
	var at: Vector2 = enemy.global_position

	var emit: float = state.emit + delta
	while emit >= DROP_INTERVAL:
		emit -= DROP_INTERVAL
		_spawn_drop(at, enemy.velocity)
	state.emit = emit

	var stacks: Array = state.stacks
	var damage: float = 0.0
	var k: int = 0
	while k < stacks.size():
		var stack: Array = stacks[k]
		if _now < stack[2]:
			k += 1
			continue
		damage += stack[0]
		stack[1] += 1
		if stack[1] >= LIFETIME_TOTAL_BLEED:
			stacks.remove_at(k)
			continue
		stack[2] += BLEED_FREQUENCY
		k += 1
	if damage > 0.0:
		global.add_damage_text(at, damage, global.DAMAGE_TYPES.PHYSICAL)
		if AchievementManager.hit(enemy, damage, &"bleed") <= 0.0:
			return false   # it died; its marks go with it

	if stacks.is_empty():
		enemy.marks.erase("bleed")
		return false
	return true


func _spawn_drop(at: Vector2, velocity: Vector2) -> void:
	var slot: int = _next_slot
	_next_slot = (_next_slot + 1) % CAPACITY
	if _live == CAPACITY:   # full: this overwrites the oldest live drop
		_oldest = (_oldest + 1) % CAPACITY
		_live -= 1
	_live += 1
	_spawn_time[slot] = _now
	if _used < CAPACITY and slot >= _used:
		_used = slot + 1
		RenderingServer.multimesh_set_visible_instances(_rid, _used)
	var offset := Vector2.from_angle(randf() * TAU) * DROP_SPREAD * sqrt(randf())
	RenderingServer.multimesh_instance_set_transform_2d(_rid, slot, Transform2D(0.0, at + offset))
	RenderingServer.multimesh_instance_set_color(_rid, slot, DROP_COLOR)
	RenderingServer.multimesh_instance_set_custom_data(_rid, slot,
		Color(velocity.x, velocity.y, _drop_clock, randf_range(DROP_SIZE_MIN, DROP_SIZE_MAX)))
