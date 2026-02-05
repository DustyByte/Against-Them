extends Node2D

var starBluePrint: PackedScene = preload("res://Scenes/star.tscn")
var summonFlags: Node2D = null
var player: CharacterBody2D = null
var stats: Dictionary = {}
var rotationRate: float = 0.0
var radius: float = 100.0


func add_starand_adjust_position() -> void:
	var star: Node2D = starBluePrint.instantiate()
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


func _ready() -> void:
	player = $'..'
	summonFlags = $'..'/SummonFlags
	
	stats = player.stats.activeModifiers.starStats
	rotationRate = TAU / stats.baseCD
	
	summonFlags.outerMostOrbitalRadiusChanged.connect(update_radius)
	radius = summonFlags.currentOuterMostOrbitalRadius


func _process(delta: float) -> void:
	rotation += delta * rotationRate * stats.attackSpeed
