class_name ProgressBarCustom
extends Node2D

@onready var BG: Sprite2D = $Pbbg
@onready var fill: Sprite2D = $PbFillLine
@export var maxValue: float = 100.0
@export var value: float = 0.0
var BGSizeWScaleX: float = -1.0


func update_visuals() -> void:
	var fillSizeX: float = BGSizeWScaleX * value / maxValue
	var beginPosX: float = -BGSizeWScaleX * 0.5
	fill.position.x = beginPosX + fillSizeX


func change_value(val: float) -> void:
	value = val
	update_visuals()


func _ready() -> void:
	BGSizeWScaleX = BG.get_rect().size.x * scale.x
	update_visuals()
