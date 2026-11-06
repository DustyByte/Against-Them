class_name  Star
extends Area2D

const DAMAGE_TYPE: int = global.DAMAGE_TYPES.INFERNO
const ON_RUN_FEATURES: Script = global.ON_RUN_FEATURES
var stats: Dictionary = {}
var scaleRightBefCollapse: Vector2
var lightTexture: Texture = preload("res://Assets/Shader Textures/ExplosionLight32.png")
#var light: PointLight2D = null
@export var scaleCollapseCurve: Curve =  null
@export var lightCollapseCurve: Curve =  null


func setup(statsGiven: Dictionary) -> void:
	stats = statsGiven


func _on_enemy_entered(enemy: Node2D) -> void:
	var d: float = stats.damage
	enemy.get_hit(d)
	global.add_damage_text(enemy.global_position, d , DAMAGE_TYPE)
	ON_RUN_FEATURES.burn_inflict(enemy, stats.burnDamage)


func collapse_method(val: float) -> void:
	scale = scaleRightBefCollapse * scaleCollapseCurve.sample_baked(val)
	#light.energy = 8.0 * lightCollapseCurve.sample_baked(val)


func handle_collapse_finish() -> void:
	var anomaly: Anomaly = load("res://Scenes/Allies&Summons/anomaly.tscn").instantiate()
	add_sibling.call_deferred(anomaly)
	anomaly.position = position
	set_process(false)
	
	var tween: Tween = get_tree().create_tween()
	var anomaly_appear_method: Callable = func(val: float):
		anomaly.scale = Vector2.ONE * scaleCollapseCurve.sample_baked(val)
	tween.tween_method(anomaly_appear_method, 1.0, 0.0, 0.2)
	tween.finished.connect(queue_free)


func collapse() -> void:
	#light = PointLight2D.new()
	#light.texture = lightTexture
	#light.texture_scale = 6.0
	#light.energy = 0.0
	scaleRightBefCollapse = scale
	#add_child(light)
	
	var tween: Tween = get_tree().create_tween()
	tween.tween_method(collapse_method, 0.0, 1.0, 0.33)
	tween.finished.connect(handle_collapse_finish)
