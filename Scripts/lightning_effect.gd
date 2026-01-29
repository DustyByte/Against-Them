extends Line2D

@onready var particleGeneratorBluePrint: PackedScene = preload("res://Scenes/lightning_particles.tscn")
@onready var animationPlayer: AnimationPlayer = $AnimationPlayer
@onready var flickeringLight: Sprite2D  = $Sprite2D
var arcRepeat: int = 0
var arcCount: int = 0
var arcRepeatInterval: float = 0.05


func arc(_trash) -> void:
	flickeringLight.isTurnedOn = true
	
	var particles: GPUParticles2D = particleGeneratorBluePrint.instantiate()
	particles.position = position
	add_sibling(particles)
	
	global.activeCamera.shake(global.SHAKE_AMOUNTS.LIGHTNING_STRIKE)
	
	var randomNum: float = randf_range(-1.0, 1.0)
	material.set_shader_parameter("randomOffset", randomNum)
	arcCount += 1
	
	if arcCount < arcRepeat:
		await get_tree().create_timer(arcRepeatInterval).timeout
		arc(1)
	else:
		queue_free()


func _ready() -> void:
	points[0] = Vector2.UP * get_window().size.length()
	
	var pointsCopy = Array(points)
	for i in range(randi_range(2, 7)):
		var point: Vector2 = Vector2(randf_range(-100.0, 100.0), randf_range(0, pointsCopy[0].y))
		for p in range(pointsCopy.size()):
			if point.y >= pointsCopy[p].y and point.y <= pointsCopy[p+1].y:
				pointsCopy.insert(p+1, point)
				break
	
	points = PackedVector2Array(pointsCopy)
	rotation_degrees = randf_range(-20, 20)
	
	arcRepeat = randi_range(4, 6)
	animationPlayer.play("strike")
	animationPlayer.animation_finished.connect(arc)
	
	flickeringLight.adjust_rotation(rotation_degrees)
