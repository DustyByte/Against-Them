extends Node2D

@onready var lightningBluePrint: PackedScene = preload("res://Scenes/lightning.tscn")


func _ready() -> void:
	global.WORLD = self
