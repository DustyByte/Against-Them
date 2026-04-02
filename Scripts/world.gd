extends Node2D

@onready var expDropMMI: MultiMeshInstance2D = $ExpDropMMI
var particleBP: PackedScene = preload("res://Scenes/Effects/particles_throw.tscn")
var GPUParticlePool: Array[GPUParticles2D] = []
var poolCount: int = 0
var expLifeTrackArr: Array[Dictionary] = []


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


func _ready() -> void:
	global.WORLD = self
	
	fill_gpu_particle_pool(10)
