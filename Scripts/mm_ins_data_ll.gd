class_name MMInstanceNode

var position: Vector2 = Vector2.ZERO
var scale: Vector2 = Vector2.ZERO
var next: MMInstanceNode = null
var prev: MMInstanceNode = null


func _init(givenPosition: Vector2, givenScale: Vector2) -> void:
	position = givenPosition
	scale = givenScale
