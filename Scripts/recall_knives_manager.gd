class_name RecallKnivesManager
extends Node2D

@onready var recallKnifeBP: PackedScene = preload("res://Scenes/Allies&Summons/recall_knife.tscn")
@onready var player: Player = global.PLAYER
var towards: Vector2 = Vector2.RIGHT
var readyAmount: int = 0
var expectedReadyAmount = -1
var s: int = 1
var offset: Vector2 = Vector2.UP * 64.0
var hasNotThrown: bool = true
var stats: Dictionary = {}
var stackAmount: int = 0


func setup(givenStats: Dictionary) -> void:
	stats = givenStats


func throw() -> void:
	stackAmount = 0
	var children: Array[Node] = get_children()
	var size: int = children.size()
	for i in range(stats.amount - size):
		var recallKnife: RecallKnife = recallKnifeBP.instantiate()
		add_child(recallKnife)
		children.append(recallKnife)
		expectedReadyAmount += 1
		readyAmount += 1
	
	var enemy: Node2D = player.get_nearest_attackable_or_null()
	if enemy:
		towards = (player.global_position + offset).direction_to(enemy.global_position)
	
	var towardsCopy: Vector2 = towards
	var child: Node = null
	var angle: float = 0.0
	for i in range(children.size()):
		child = children[i]
		angle = i*0.174533*s
		s *= -1
		
		towardsCopy = towardsCopy.rotated(angle)
		child.throw(towardsCopy)
	
	readyAmount = 0
	hasNotThrown = true


func _ready() -> void:
	expectedReadyAmount = get_child_count()
	readyAmount = expectedReadyAmount


func _process(_delta: float) -> void:
	print(stackAmount)
	if hasNotThrown and readyAmount == expectedReadyAmount:
		get_tree().create_timer(stats.cd).timeout.connect(throw)
		hasNotThrown = false
