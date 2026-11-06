extends Node2D

var stats: Dictionary = {}
var fieldFireBP: PackedScene = preload("res://Scenes/Allies&Summons/field_fire.tscn")
var rangeRectHalfX: float = -1.0
var rangeRectHalfY: float = -1.0
var launchFromOffset: Vector2 = Vector2(0, -1000.0)
@onready var player: CharacterBody2D = global.PLAYER


func setup(statsGiven: Dictionary) -> void:
	stats = statsGiven


func throw() -> void:
	for i in range(stats.amount):
		var fieldFire: FieldFire = fieldFireBP.instantiate()
		add_child(fieldFire)
		
		var playerPos: Vector2 = player.global_position
		fieldFire.launch(playerPos + launchFromOffset, Vector2(randf_range(playerPos.x - rangeRectHalfX, playerPos.x + rangeRectHalfX), randf_range(playerPos.y - rangeRectHalfY, playerPos.y + rangeRectHalfY)))
	
	get_tree().create_timer(stats.cd, false).timeout.connect(throw)


func _ready() -> void:
	var rangeRectHalf: Vector2 = get_viewport().get_visible_rect().size * 0.375 # 0.75 * 0.5 = 0.375
	rangeRectHalfX = rangeRectHalf.x
	rangeRectHalfY = rangeRectHalf.y
	
	throw()
