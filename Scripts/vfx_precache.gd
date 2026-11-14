extends Control

signal done_caching

const VFX_SCENES: Array[PackedScene] = [
	preload("res://Scenes/Weapons/rupture_ammo.tscn"),
	preload("res://Scenes/Weapons/torcher_ammo.tscn"),
	preload("res://Scenes/Effects/bleed.tscn"),
	preload("res://Scenes/Effects/burn_emission.tscn"),
	preload("res://Scenes/Effects/explosion_particles.tscn"),
	preload("res://Scenes/Effects/lightning_particles.tscn"),
	preload("res://Scenes/Effects/particles_throw.tscn"),
]

const SHADER_MATERIALS: Array[ShaderMaterial] = [
	preload("res://Shaders/Material/enemy_death_corrode.tres"),
	preload("res://Shaders/Material/freeze_shader_mat.tres"),
	preload("res://Shaders/Material/gravity_bomb_explosion_shader_mat.tres"),
	preload("res://Shaders/Material/gravity_bomb_inward_pull_shader_mat.tres"),
	preload("res://Shaders/Material/scale_shader_mat.tres"),
	preload("res://Shaders/Material/tornado_trail_shader_mat.tres"),
	preload("res://Shaders/Material/wave_heading_fade_mat.tres")
]

const SHADERS: Array[Shader] = [
	preload("res://Shaders/corrode.gdshader"),
	preload("res://Shaders/explosion.gdshader"),
	preload("res://Shaders/fiery_bullet.gdshader"),
	preload("res://Shaders/freeze.gdshader"),
	preload("res://Shaders/gradient_fade.gdshader"),
	preload("res://Shaders/grass_depth_for_player.gdshader"),
	preload("res://Shaders/gravityBomb.gdshader"),
	preload("res://Shaders/hit.gdshader"),
	preload("res://Shaders/lighting_light.gdshader"),
	preload("res://Shaders/lightning.gdshader"),
	preload("res://Shaders/hp_vessel.gdshader"),
	preload("res://Shaders/exp_bar.gdshader"),
	preload("res://Shaders/weapon_card.gdshader"),
	preload("res://Shaders/pause_button.gdshader"),
	preload("res://Shaders/joystick.gdshader"),
	preload("res://Shaders/fire_button.gdshader"),
	preload("res://Shaders/starryGlow.gdshader"),
	preload("res://Shaders/suction.gdshader"),
	preload("res://Shaders/tornado.gdshader"),
	preload("res://Shaders/wave_heading_fade.gdshader"),
	preload("res://Shaders/tornado.gdshader")
]
const BACKGROUND_IMAGE_DIMENSION: Vector2 = Vector2(1024, 1024)

@onready var holder: Node2D = $Holder
var total_objects_to_cache: int = 0
var objects_cached: int = 0:
	set(val):
		$VBoxContainer/ProgressBar.value = val
		objects_cached = val

func _ready() -> void:
	var windowDim: Vector2 = get_viewport_rect().size
	$Cover.scale = windowDim / BACKGROUND_IMAGE_DIMENSION
	$Cover.position = windowDim * 0.5
	
	total_objects_to_cache = VFX_SCENES.size() + SHADER_MATERIALS.size() + SHADERS.size()
	$VBoxContainer/ProgressBar.max_value = total_objects_to_cache
	cache_vfx()
	
	done_caching.connect(get_tree().change_scene_to_file.bind("res://Scenes/home.tscn"))

func cache_vfx() -> void:
	var instanced_nodes: Array[Node] = []
	
	for mat in SHADER_MATERIALS:
		if mat:
			var dummy := Sprite2D.new()
			dummy.material = mat.duplicate()
			dummy.z_index = -1
			holder.add_child(dummy)
			instanced_nodes.append(dummy)
			objects_cached += 1

	for scene in VFX_SCENES:
		if scene:
			var instance := scene.instantiate()
			if instance:
				instance.set_script(null)
				instance.z_index = -1
				if instance is GPUParticles2D:
					instance.emitting = true
				holder.add_child(instance)
				instanced_nodes.append(instance)
				objects_cached += 1
	
	for shader in SHADERS:
		if shader:
			var material := ShaderMaterial.new()
			material.shader = shader
			var dummy := Sprite2D.new()
			dummy.material = material
			dummy.z_index = -1
			holder.add_child(dummy)
			instanced_nodes.append(dummy)
			objects_cached += 1
	
	await get_tree().create_timer(0.1).timeout
	
	for node in instanced_nodes:
		node.queue_free()
	
	done_caching.emit()
