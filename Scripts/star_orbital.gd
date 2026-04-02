class_name StarOrbital
extends Node2D

var starBP: PackedScene = preload("res://Scenes/Allies&Summons/star.tscn")
var anomalyBP: PackedScene = preload("res://Scenes/Allies&Summons/anomaly.tscn")
var summonFlags: Node2D = null
var player: CharacterBody2D = null
var stats: Dictionary = {}
var rotationRate: float = 0.0
var radius: float = 100.0
var nowAsBH: bool = false
var currentScaleStar: Vector2 = Vector2.ONE


func add_starand_adjust_position() -> void:
	var star := anomalyBP.instantiate() if nowAsBH else starBP.instantiate()
	if star is Star:
		star.scale = currentScaleStar
		star.setup(stats)
	add_child(star)
	
	var stars: Array = get_children()
	var thetaBetweenEach: float = TAU / stars.size()
	
	for index in range(stars.size()):
		stars[index].position = Vector2.LEFT.rotated(thetaBetweenEach * index) * radius


func update_radius(updatedRadius: float) -> void:
	radius = updatedRadius
	
	for child in get_children():
		var direction: Vector2 = child.position.normalized()
		child.position = direction * radius


func collapse_all_stars_into_blackhole() -> void:
	var stars: Array = get_children()
	for star in stars:
		star.collapse()


func increase_all_star_size(mult: float) -> void:
	var stars: Array = get_children()
	var dir: Vector2
	radius += 0.0 if nowAsBH else 7.0
	currentScaleStar = stars[0].scale * mult
	for star in stars:
		star.scale = currentScaleStar
		dir = star.position.normalized()
		star.position = dir * radius


func _ready() -> void:
	player = $'..'
	summonFlags = $'..'/SummonFlags
	
	stats = player.stats.activeModifiers.starStats
	
	summonFlags.outerMostOrbitalRadiusChanged.connect(update_radius)
	radius = summonFlags.currentOuterMostOrbitalRadius


func _process(delta: float) -> void:
	rotation += delta / stats.cd
