extends Node2D

@onready var player: CharacterBody2D = $".."
@onready var animationPlayer: AnimationPlayer = $AnimationPlayer
var isHitAnimationPlaying: bool = false
var hitShaderSlider: float = 0.0
var hitAnimationDelta: float = 0.2 * 5 / 12

# call this function when another "animation interrupting event" other than "hit" has occured. 
func reset_hit_animation_leftovers() -> void:
	hitShaderSlider = 0.0
	set_material(null)


func handle_hit_animation() -> void:
	var shaderMaterial: ShaderMaterial = ShaderMaterial.new()
	shaderMaterial.set_shader(load("res://Shaders/hit.gdshader"))
	set_material(shaderMaterial)
	isHitAnimationPlaying = true


func _process(_delta: float) -> void:
	if isHitAnimationPlaying:
		material.set_shader_parameter("alphaIntensity", hitShaderSlider)
		hitShaderSlider += hitAnimationDelta
		
		if hitShaderSlider > 1.0:
			isHitAnimationPlaying = false
			set_material(null)
			hitShaderSlider = 0.0
		return
	
	if player.velocity:
		animationPlayer.play("run")
	else:
		animationPlayer.play("idle")
