extends Node2D

@onready var expDropMMI: MultiMeshInstance2D = $ExpDropMMI
var particleBP: PackedScene = preload("res://Scenes/Effects/particles_throw.tscn")
var GPUParticlePool: Array[GPUParticles2D] = []
var ASP2dPool: Array[AudioStreamPlayer2D] = []
var ASPPool: Array[AudioStreamPlayer] = []
var ASP2dPoolSize: int = 0
var ASPPoolSize: int = 0
var poolCount: int = 0
var expLifeTrackArr: Array[Dictionary] = []
var elapsedTime: float = 0.0


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


func clean_expdropmm() -> void:
	var latestTrack: Dictionary = {}
	var expDropMMIRID: RID = expDropMMI.multimesh.get_rid()
	var vcount: int = RenderingServer.multimesh_get_visible_instances(expDropMMIRID)
	var usedCounter: int = 0
	
	for i in range(vcount):
		var xform: Transform2D = RenderingServer.multimesh_instance_get_transform_2d(expDropMMIRID, i)
		if xform.get_scale().x == 0:
			usedCounter += 1
		elif usedCounter:
			RenderingServer.multimesh_instance_set_transform_2d(expDropMMIRID, i, xform.scaled(Vector2.ZERO))
			
			var newId: int = i - usedCounter
			var col: Color = RenderingServer.multimesh_instance_get_color(expDropMMIRID, i)
			RenderingServer.multimesh_instance_set_transform_2d(expDropMMIRID, newId, xform)
			RenderingServer.multimesh_instance_set_color(expDropMMIRID, newId, col)
			latestTrack[str(i)] = newId
	
	if usedCounter:
		RenderingServer.multimesh_set_visible_instances(expDropMMIRID, vcount - usedCounter)
		expLifeTrackArr.append(latestTrack)
	else:
		var buffer: PackedFloat32Array = RenderingServer.multimesh_get_buffer(expDropMMIRID)
		var additionalBuffer: PackedFloat32Array = PackedFloat32Array([])
		additionalBuffer.resize(500*12)
		buffer = buffer + additionalBuffer
		
		RenderingServer.multimesh_allocate_data(expDropMMIRID, vcount+500, RenderingServer.MULTIMESH_TRANSFORM_2D, true, false)
		RenderingServer.multimesh_set_buffer(expDropMMIRID, buffer)


func get_exp_latest_id(oldId: int) -> int:
	for track in expLifeTrackArr:
		if track.has(str(oldId)):
			oldId = track[str(oldId)]
	return oldId


func remove_exp_id_lifetrack(id: int) -> void:
	var nextId: int = -1
	for i in range(expLifeTrackArr.size()):
		var track: Dictionary = expLifeTrackArr[i]
		if track.has(str(id)):
			nextId = track[str(id)]
			track.erase(str(id))
			id = nextId
			
			if not track.keys().size():
				expLifeTrackArr.remove_at(i)


func fill_audio_stream_player_2d_pool(amount: int) -> void:
	ASP2dPool.resize(amount)
	ASP2dPoolSize = amount
	for i in range(amount):
		ASP2dPool[i] = AudioStreamPlayer2D.new()
		ASP2dPool[i].process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(ASP2dPool[i])


var nextASP2d: int = 0
func audio_2d_play(AS: AudioStream, enemyGlobalPosition: Vector2, sfxType: String, pitch: float = 0.0, vdb: float = 0.0) -> void:
	if not global.SFX_TYPES_PERM[sfxType]:
		return
	
	ASP2dPool[nextASP2d].global_position = enemyGlobalPosition
	ASP2dPool[nextASP2d].stream = AS
	ASP2dPool[nextASP2d].play()
	if pitch:
		ASP2dPool[nextASP2d].pitch_scale = pitch
		if vdb:
			ASP2dPool[nextASP2d].volume_db = vdb
	
	
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
	
	ASPPool[nextASP].stream = AS
	ASPPool[nextASP].play()
	if pitch:
		ASPPool[nextASP].pitch_scale = pitch
		if vdb:
			ASPPool[nextASP].volume_db = vdb
	
	nextASP = (nextASP+1) % ASPPoolSize


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		pass


func _ready() -> void:
	global.WORLD = self
	AchievementManager.start_run()
	var achievementBanners: Node = preload("res://Scripts/achievement_banner_presenter.gd").new()
	achievementBanners.name = "AchievementBannerPresenter"
	$CanvasLayer.add_child(achievementBanners)
	
	fill_gpu_particle_pool(10)
	fill_audio_stream_player_2d_pool(16)
	fill_audio_stream_player_pool(6)


func _process(delta: float) -> void:
	elapsedTime += delta
