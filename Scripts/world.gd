extends Node2D

@onready var expDrops: ExpDrops = $ExpDropMMI
var particleBP: PackedScene = preload("res://Scenes/Effects/particles_throw.tscn")
var GPUParticlePool: Array[GPUParticles2D] = []
var ASP2dPool: Array[AudioStreamPlayer2D] = []
var ASPPool: Array[AudioStreamPlayer] = []
var ASP2dPoolSize: int = 0
var ASPPoolSize: int = 0
var poolCount: int = 0
var elapsedTime: float = 0.0
## Floating damage numbers (global.add_damage_text). Made here, before any
## child is ready, so it is never missing when the first hit lands.
var damageNumbers: DamageNumbers = null
## Keeps enemies from piling onto each other (they don't collide physically).
var enemyCrowd: EnemyCrowd = null
## Clock for the enemy body animation in enemy.gdshader. Unlike the shader's
## own TIME it stops while the game is paused or the world is frozen. Wraps
## every 4 s, a whole number of every enemy animation's cycles.
var enemyAnimTime: float = 0.0
const ENEMY_ANIM_TIME_WRAP: float = 4.0


func _init() -> void:
	damageNumbers = DamageNumbers.new()
	damageNumbers.name = "DamageNumbers"
	add_child(damageNumbers)
	enemyCrowd = EnemyCrowd.new()
	enemyCrowd.name = "EnemyCrowd"
	add_child(enemyCrowd)


func fill_gpu_particle_pool(amount: int) -> void:
	GPUParticlePool.resize(amount)

	for i in range(amount):
		var p: GPUParticles2D = particleBP.instantiate()
		add_child(p)
		p.emitting = false
		GPUParticlePool[i] = p


func get_throwable_gpu_particles() -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticlePool[poolCount]

	poolCount += 1
	if poolCount == GPUParticlePool.size():
		poolCount = 0

	return p


func fill_audio_stream_player_2d_pool(amount: int) -> void:
	ASP2dPool.resize(amount)
	ASP2dPoolSize = amount
	for i in range(amount):
		ASP2dPool[i] = AudioStreamPlayer2D.new()
		ASP2dPool[i].process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(ASP2dPool[i])


## `pitch` 0 means normal pitch. Pitch and volume are set on every play: the
## players are reused, so a boosted sound must not leave later sounds boosted.
var nextASP2d: int = 0
func audio_2d_play(AS: AudioStream, enemyGlobalPosition: Vector2, sfxType: String, pitch: float = 0.0, vdb: float = 0.0) -> void:
	if not global.SFX_TYPES_PERM[sfxType]:
		return

	var player: AudioStreamPlayer2D = ASP2dPool[nextASP2d]
	player.global_position = enemyGlobalPosition
	player.stream = AS
	player.pitch_scale = pitch if pitch > 0.0 else 1.0
	player.volume_db = vdb
	player.play()

	nextASP2d = (nextASP2d+1) % ASP2dPoolSize


func fill_audio_stream_player_pool(amount: int) -> void:
	ASPPool.resize(amount)
	ASPPoolSize = amount
	for i in range(amount):
		ASPPool[i] = AudioStreamPlayer.new()
		add_child(ASPPool[i])


var nextASP: int = 0
func audio_play(AS: AudioStream, sfxType: StringName, pitch: float = 0.0, vdb: float = 0.0) -> void:
	if not global.SFX_TYPES_PERM[sfxType]:
		return

	var player: AudioStreamPlayer = ASPPool[nextASP]
	player.stream = AS
	player.pitch_scale = pitch if pitch > 0.0 else 1.0
	player.volume_db = vdb
	player.play()

	nextASP = (nextASP+1) % ASPPoolSize


func _ready() -> void:
	global.WORLD = self
	global.TOTAL_ENEMY_KILLS = 0 # per-run count (shown on results, used by Harvest)
	global.RUN_REVIVES = 0
	AchievementManager.start_run()
	var achievementBanners: Node = preload("res://Scripts/achievement_banner_presenter.gd").new()
	achievementBanners.name = "AchievementBannerPresenter"
	$CanvasLayer.add_child(achievementBanners)

	fill_gpu_particle_pool(10)
	fill_audio_stream_player_2d_pool(16)
	fill_audio_stream_player_pool(6)


func _process(delta: float) -> void:
	elapsedTime += delta
	enemyAnimTime = fmod(enemyAnimTime + delta, ENEMY_ANIM_TIME_WRAP)
	RenderingServer.global_shader_parameter_set(&"enemy_time", enemyAnimTime)
	if is_instance_valid(global.PLAYER):
		AchievementManager.register_run_time(elapsedTime, delta, global.PLAYER.stats.currentHP)
