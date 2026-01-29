extends Area2D

var expAmount: float = 0
var color: Color
var isPickedUp: bool = false


func set_exp_type(givenExpType: Dictionary) -> void:
	expAmount = givenExpType.expAmount
	color = givenExpType.color


func _ready() -> void:
	$Polygon2D.color = color
