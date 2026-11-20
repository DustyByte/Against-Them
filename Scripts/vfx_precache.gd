extends Control

## Launch screen. While the player sees "Unpacking resources" and a bar, it
## 1) loads the gameplay scenes and the home screen on a background thread, then
## 2) draws every gameplay visual once behind the cover, so each shader is
##    compiled now instead of stalling the first frame it appears in a run.
## The Compatibility renderer compiles a shader the first time something is
## drawn with it (and again for each way it's drawn: sprite, line, multimesh,
## particles), so the real scenes are drawn, not just their shader files.
##
## Warm-up copies have their scripts removed before entering the tree, so no
## game logic runs; everything is still drawn as the scene file describes.

## Scenes drawn once. Their materials, shaders and particles get compiled the
## way the game draws them. world.tscn brings the player, map, grass, HUD,
## joystick and EXP drops along.
const WARM_SCENES: Array[String] = [
	"res://Scenes/world.tscn",
	"res://Scenes/Enemies/enemy_1.tscn",
	"res://Scenes/Enemies/enemy_4.tscn",
	"res://Scenes/Enemies/enemy_6.tscn",
	"res://Scenes/Allies&Summons/anomaly.tscn",
	"res://Scenes/Allies&Summons/aura.tscn",
	"res://Scenes/Allies&Summons/cryolite.tscn",
	"res://Scenes/Allies&Summons/field_fire.tscn",
	"res://Scenes/Allies&Summons/gravity_bomb.tscn",
	"res://Scenes/Allies&Summons/hexa_snail.tscn",
	"res://Scenes/Allies&Summons/icicle.tscn",
	"res://Scenes/Allies&Summons/laser_orb.tscn",
	"res://Scenes/Allies&Summons/recall_knife.tscn",
	"res://Scenes/Allies&Summons/star.tscn",
	"res://Scenes/Allies&Summons/tornado.tscn",
	"res://Scenes/Effects/burn_emission.tscn",
	"res://Scenes/Effects/explosion_particles.tscn",
	"res://Scenes/Effects/freeze.tscn",
	"res://Scenes/Effects/lightning.tscn",
	"res://Scenes/Effects/lightning_particles.tscn",
	"res://Scenes/Effects/particles_throw.tscn",
	"res://Scenes/Weapons/rupture_ammo.tscn",
	"res://Scenes/Weapons/torcher_ammo.tscn",
	"res://Scenes/Systems/retribution_manager.tscn",
	"res://Scenes/HUD/wave_heading.tscn",
	"res://Scenes/HUD/option_display.tscn",
	"res://Scenes/HUD/achievement_banner.tscn",
	"res://Scenes/HUD/death_screen.tscn",
]

## Materials and shaders that scripts put on things at run time, so no scene
## file shows them. Each is drawn on a plain sprite.
const WARM_MATERIALS: Array[String] = [
	"res://Shaders/Material/enemy.tres",
	"res://Shaders/Material/enemy_boss.tres",
	"res://Shaders/Material/enemy_death_corrode.tres",
	"res://Shaders/Material/freeze_shader_mat.tres",
	"res://Shaders/Material/gravity_bomb_explosion_shader_mat.tres",
	"res://Shaders/Material/gravity_bomb_inward_pull_shader_mat.tres",
	"res://Shaders/Material/scale_shader_mat.tres",
	"res://Shaders/Material/tornado_trail_shader_mat.tres",
	"res://Shaders/Material/wave_heading_fade_mat.tres",
]
const WARM_SHADERS: Array[String] = [
	"res://Shaders/hit.gdshader",
	"res://Shaders/starryGlow.gdshader",
	"res://Shaders/joystick.gdshader",
	"res://Shaders/Skins/skin_ember_warden.gdshader",
	"res://Shaders/Skins/skin_frostbound.gdshader",
	"res://Shaders/Skins/skin_voidwalker.gdshader",
]
const NEXT_SCENE: String = "res://Scenes/home.tscn"

## Frames each warm-up copy stays drawn. Particles need a few: one to start
## simulating, then draws of the live particles.
const FRAMES_PER_ITEM: int = 3
const SPRITES_PER_STEP: int = 3   # material sprites drawn together
## Share of the bar for loading (the rest is the warm-up).
const LOAD_SHARE: float = 0.4

@onready var warmRoot: Node2D = $WarmUp
@onready var bar: ProgressBar = $Cover/Center/Column/Bar
@onready var statusLabel: Label = $Cover/Center/Column/Status
@onready var percentLabel: Label = $Cover/Center/Column/Percent

var _quad: Texture2D = null


func _ready() -> void:
	bar.max_value = 1.0
	_set_progress(0.0)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_quad = ImageTexture.create_from_image(img)
	_run.call_deferred()


func _set_progress(value: float) -> void:
	bar.value = value
	percentLabel.text = "%d%%" % roundi(value * 100.0)


func _run() -> void:
	# 1. Load on a background thread; the bar moves with the loader.
	var paths: Array[String] = []
	paths.append_array(WARM_SCENES)
	paths.append_array(WARM_MATERIALS)
	paths.append_array(WARM_SHADERS)
	paths.append(NEXT_SCENE)
	for path in paths:
		ResourceLoader.load_threaded_request(path)
	var progress: Array = []
	while true:
		var sum: float = 0.0
		var pending: bool = false
		for path in paths:
			var status := ResourceLoader.load_threaded_get_status(path, progress)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				pending = true
				sum += float(progress[0]) if not progress.is_empty() else 0.0
			else:
				sum += 1.0
		_set_progress(LOAD_SHARE * sum / paths.size())
		if not pending:
			break
		await get_tree().process_frame
	var loaded: Dictionary = {}
	for path in paths:
		loaded[path] = ResourceLoader.load_threaded_get(path)

	# 2. Draw everything once behind the cover.
	statusLabel.text = "PREPARING EFFECTS"
	var center: Vector2 = get_viewport_rect().size * 0.5
	var steps: int = WARM_SCENES.size() + ceili(float(WARM_MATERIALS.size() + WARM_SHADERS.size()) / SPRITES_PER_STEP)
	var done: int = 0
	for path in WARM_SCENES:
		var packed: PackedScene = loaded[path]
		if packed:
			var node: Node = packed.instantiate()
			_strip_for_warm_up(node)
			if node is Node2D:
				node.position = center
			warmRoot.add_child(node)
			await _hold_frames()
			node.queue_free()
		done += 1
		_set_progress(LOAD_SHARE + (1.0 - LOAD_SHARE) * done / steps)

	var materials: Array[Material] = []
	for path in WARM_MATERIALS:
		if loaded[path]:
			materials.append(loaded[path])
	for path in WARM_SHADERS:
		if loaded[path]:
			var m := ShaderMaterial.new()
			m.shader = loaded[path]
			materials.append(m)
	var i: int = 0
	while i < materials.size():
		var batch: Array[Node] = []
		for k in range(i, mini(i + SPRITES_PER_STEP, materials.size())):
			var s := Sprite2D.new()
			s.texture = _quad
			s.material = materials[k]
			s.position = center
			warmRoot.add_child(s)
			batch.append(s)
		await _hold_frames()
		for s in batch:
			s.queue_free()
		i += SPRITES_PER_STEP
		done += 1
		_set_progress(LOAD_SHARE + (1.0 - LOAD_SHARE) * done / steps)

	_set_progress(1.0)
	await get_tree().process_frame
	get_tree().change_scene_to_packed(loaded[NEXT_SCENE])


func _hold_frames() -> void:
	for f in FRAMES_PER_ITEM:
		await get_tree().process_frame


## Makes a scene copy safe to put in the tree and sure to be drawn: removes
## every script (no game logic, no autoload lookups), stops sounds and
## animations, shows hidden parts and starts particles.
func _strip_for_warm_up(node: Node) -> void:
	node.set_script(null)
	if node is CanvasLayer:
		node.visible = true
	elif node is CanvasItem:
		node.visible = true
		node.modulate.a = 1.0
		node.self_modulate.a = 1.0
	if node is GPUParticles2D:
		node.one_shot = false
		node.emitting = true
	elif node is CPUParticles2D:
		node.emitting = true
	elif node is MultiMeshInstance2D:
		# Filled in by scripts in game; give it one instance so it draws.
		if node.multimesh and node.multimesh.instance_count == 0:
			var mm: MultiMesh = node.multimesh.duplicate()
			mm.instance_count = 1
			mm.set_instance_transform_2d(0, Transform2D.IDENTITY)
			if mm.use_colors:
				mm.set_instance_color(0, Color.WHITE)
			node.multimesh = mm
	elif node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		node.autoplay = false
		node.stream = null
	elif node is AnimationPlayer:
		node.autoplay = ""
		node.active = false
	elif node is Timer:
		node.autostart = false
	elif node is CollisionObject2D:
		# Nothing to touch, so no collision signals. (Disabling processing
		# instead would freeze the particles under it, leaving them uncompiled.)
		node.collision_layer = 0
		node.collision_mask = 0
		if node is Area2D:
			node.monitoring = false
			node.monitorable = false
	elif node is Camera2D:
		node.enabled = false
	for child in node.get_children():
		_strip_for_warm_up(child)
