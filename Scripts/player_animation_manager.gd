extends Node2D

@onready var player: CharacterBody2D = get_node("/root/World/Player")
@onready var animationPlayer: AnimationPlayer = $AnimationPlayer
var hitAnimationShader := preload("res://Shaders/hit.gdshader")
# Skin shader for Echo, from the skin equipped in the Inventory (null for the
# default look). The hit flash swaps it out briefly and puts it back.
var skinShader: Shader = preload("res://Scripts/skin_data.gd").load_shader(InventoryManager.equipped_skin)
var isHitAnimationPlaying: bool = false
var hitShaderSlider: float = 0.0
var hitAnimationDelta: float = 0.2 * 5 / 12

# call this function when another "animation interrupting event" other than "hit" has occured. 
func reset_hit_animation_leftovers() -> void:
	hitShaderSlider = 0.0
	material.set_shader(skinShader)


func _ready() -> void:
	material.set_shader(skinShader)


func handle_hit_animation() -> void:
	material.set_shader(hitAnimationShader)
	isHitAnimationPlaying = true


func _process(_delta: float) -> void:
	if isHitAnimationPlaying:
		material.set_shader_parameter("alphaIntensity", hitShaderSlider)
		hitShaderSlider += hitAnimationDelta
		
		if hitShaderSlider > 1.0:
			isHitAnimationPlaying = false
			reset_hit_animation_leftovers()
		return
	
	if player.velocity:
		animationPlayer.play("run")
	else:
		animationPlayer.play("idle")
