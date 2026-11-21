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
## Every bleed (Recall Dagger) and its drops (on_run_features.bleed_inflict).
var bleedSystem: BleedSystem = null
## Every burn and its flames (on_run_features.burn_inflict).
var burnSystem: BurnSystem = null
## elapsedTime from which the next enemy 4 may leap. One leap at a time across
## the whole field: each leap pushes this forward by the shared cooldown.
var enemyLeapReadyAt: float = 0.0
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
	bleedSystem = BleedSystem.new()
	bleedSystem.name = "BleedSystem"
	add_child(bleedSystem)
	burnSystem = BurnSystem.new()
	burnSystem.name = "BurnSystem"
	add_child(burnSystem)


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


## Run music: a calm opening that builds, then plays its last two minutes on
## repeat (the loop point is set in the file's import settings). Keeps
## playing through pauses and level-up choices. Follows the Music setting.
const RUN_MUSIC: AudioStream = preload("res://Assets/Music/descend_music.wav")
const RUN_MUSIC_VOLUME_DB: float = -4.0
var runMusic: AudioStreamPlayer = null


func _start_run_music() -> void:
	if not SettingsManager.settings.music:
		return
	runMusic = AudioStreamPlayer.new()
	runMusic.name = "RunMusic"
	runMusic.stream = RUN_MUSIC
	runMusic.process_mode = Node.PROCESS_MODE_ALWAYS
	runMusic.volume_db = -40.0
	add_child(runMusic)
	runMusic.play()
	var fadeIn := create_tween().tween_property(runMusic, "volume_db", RUN_MUSIC_VOLUME_DB, 2.0)
	fadeIn.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The run is over (results screen): the music fades away and stops.
func fade_out_run_music(time: float = 1.5) -> void:
	if runMusic == null or not runMusic.playing:
		return
	var fadeOut := create_tween()
	fadeOut.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # the tree is paused behind the results
	fadeOut.tween_property(runMusic, "volume_db", -60.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fadeOut.tween_callback(runMusic.stop)


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
	_start_run_music()


func _process(delta: float) -> void:
	elapsedTime += delta
	enemyAnimTime = fmod(enemyAnimTime + delta, ENEMY_ANIM_TIME_WRAP)
	RenderingServer.global_shader_parameter_set(&"enemy_time", enemyAnimTime)
	if is_instance_valid(global.PLAYER):
		AchievementManager.register_run_time(elapsedTime, delta, global.PLAYER.stats.currentHP)
