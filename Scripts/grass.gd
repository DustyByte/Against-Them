extends Node2D

@onready var grassSprite: Texture = preload("res://Assets/Grass leaf.png")
var generator: PoissonDiscSampling = PoissonDiscSampling.new()


func spawn_grass(toSpawnAt: Vector2) -> void:
	var grass: Sprite2D = Sprite2D.new()
	grass.texture = grassSprite
	grass.position = toSpawnAt
	grass.rotation_degrees = randi_range(-10, 20)
	grass.scale *= randf_range(0.85, 1.05)
	add_child(grass)


func _ready() -> void:
	for patchNum in range(30):
		var points: PackedVector2Array = generator.generate_points_for_circle(Vector2(randf_range(-1920, 1920), randf_range(-1080, 1080)), 320, 40, 1)
		for point in points:
			spawn_grass(point)
