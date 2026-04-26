extends Node2D

var playerStats: PlayerStats = null
var fluidSprite: Sprite2D = null
@export_range(0.0, 1.0, 0.001) var screenPositionX: float
@export_range(0.0, 1.0, 0.001) var screenPositionY: float
var tween: Tween = null
var currentFillLvl: float = 0.0


func update_indicator(currentHP, maxHP) -> void:
	var fluidMat: ShaderMaterial = fluidSprite.material
	var fillLvl: float = clampf(1-currentHP/maxHP, 0.0, 1.0)
	
	if tween:
		tween.kill()
	
	tween = get_tree().create_tween()
	
	tween.tween_method(func(val: float):
		fluidMat.set_shader_parameter("fill_level", val)
		currentFillLvl = val
	, currentFillLvl, fillLvl, 0.25)
	
	tween.finished.connect(func():
		tween = null
	)


func _ready() -> void:
	var windowDim: Vector2 = get_window().get_size()
	position = windowDim * Vector2(screenPositionX, screenPositionY)
	
	var player: Player = $"../../Player"
	playerStats = player.stats
	fluidSprite = $FluidBaseSprite
	player.hp_changed.connect(update_indicator)
