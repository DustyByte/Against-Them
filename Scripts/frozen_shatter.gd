class_name FrozenShatter
extends MultiMeshInstance2D

## How frozen enemies die: their iced body cracks and crumbles into shards
## (Shaders/frozen_shatter.gdshader on the enemy) while ice dust bursts out
## (Shaders/ice_dust.gdshader). One of these lives in the world and draws the
## dust of every shatter in one MultiMesh: a burst only fills MOTES slots, the
## motion is all in the shader, and it stops processing once the last mote
## is gone.

const SHATTER_SHADER: Shader = preload("res://Shaders/frozen_shatter.gdshader")
const DUST_SHADER: Shader = preload("res://Shaders/ice_dust.gdshader")
const SHATTER_TIME: float = 0.55
## When in the shatter the dust bursts out (as the first shards break off).
const DUST_DELAY: float = 0.15
const MOTES: int = 30
const DUST_LIFE: float = 0.85
## Bursts that can be in the air at once; more reuse the oldest motes.
const MAX_BURSTS: int = 16
## The enemy's radius at scale 1, so cracks and crumbling cover the body.
const BODY_RADIUS: float = 45.0
## Where the dust comes from, relative to the enemy's position (its middle).
const DUST_OFFSET: Vector2 = Vector2(0, -30)

var _dust_material: ShaderMaterial
var _clock: float = 0.0
var _busy_until: float = 0.0
var _slot: int = 0


func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(7, 7)
	multimesh = MultiMesh.new()
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = MOTES * MAX_BURSTS
	for i in multimesh.instance_count:
		multimesh.set_instance_custom_data(i, Color(-100.0, 0, 0, 0))   # long gone
	_dust_material = ShaderMaterial.new()
	_dust_material.shader = DUST_SHADER
	_dust_material.set_shader_parameter("life", DUST_LIFE)
	material = _dust_material
	z_index = 1
	set_process(false)


func _process(delta: float) -> void:
	_clock += delta
	_dust_material.set_shader_parameter("now", _clock)
	if _clock > _busy_until:
		set_process(false)


## Plays the shatter on a dying frozen enemy (its Wrapper already draws its
## sprites with one material, set up by the freeze) and calls `on_done` once
## the body is gone.
func shatter(enemy: Node2D, wrapper: Node2D, on_done: Callable) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHATTER_SHADER
	mat.set_shader_parameter("body_radius", BODY_RADIUS * absf(enemy.scale.x))
	wrapper.modulate = Color.WHITE   # it held the bob phase for enemy.gdshader
	wrapper.use_parent_material = false
	for child in wrapper.get_children():
		if child is CanvasItem:
			child.use_parent_material = true
	wrapper.material = mat

	var at: Vector2 = enemy.global_position + DUST_OFFSET * absf(enemy.scale.x)
	var tween: Tween = enemy.get_tree().create_tween()
	# tween_method: a fresh material has no "progress" property to tween yet.
	tween.tween_method(func(p: float): mat.set_shader_parameter("progress", p), 0.0, 1.0, SHATTER_TIME)
	tween.parallel().tween_callback(burst.bind(at)).set_delay(DUST_DELAY)
	tween.finished.connect(on_done)


func burst(at: Vector2) -> void:
	var count: int = multimesh.instance_count
	for i in MOTES:
		var s: int = _slot
		_slot = (_slot + 1) % count
		var jitter := Vector2(randf_range(-18.0, 18.0), randf_range(-40.0, 10.0))
		multimesh.set_instance_transform_2d(s, Transform2D(0.0, at + jitter))
		multimesh.set_instance_custom_data(s, Color(_clock + randf() * 0.12, randf() * 1000.0, 0, 0))
	_busy_until = _clock + 0.12 + DUST_LIFE
	set_process(true)
