class_name Icicle
extends Area2D

const SPEED: float = 1000.0

var freezeDur: float = -1.0
var carryingDamage: float = -1.0
var carryingDamageType: int = -1
var carryingKnockBackIntensity: float = -1.0
var goingTowards: Vector2 = Vector2.ZERO
var lifeSteal: float = 0.0
var travelledDisSq: float = 0.0
var toExplode: bool = false
@onready var iceFlakes: GPUParticles2D = $GPUParticles2D


func setup(direction: Vector2, carryDamage: float, carryDamageType: int, carryKnockBackIntensity: float, freezeDuration: float = 2.0, carryingLifeSteal: float = 0.0, shouldExplode: bool = false) -> void:
	toExplode = shouldExplode
	carryingDamage = carryDamage
	carryingDamageType = carryDamageType
	carryingKnockBackIntensity = carryKnockBackIntensity
	goingTowards = direction
	freezeDur = freezeDuration
	rotation += Vector2.LEFT.angle_to(direction)
	lifeSteal = carryingLifeSteal


func hit(body: Node2D) -> void:
	if body.is_in_group('enemy'):
		var remHP: float = body.get_hit(carryingDamage)
		if toExplode and remHP <= 0.0:
			explode_into_icicles(body.global_position, 3)
		body.get_knocked_back(goingTowards, carryingKnockBackIntensity)
		global.add_damage_text(body.global_position, carryingDamage, carryingDamageType)
		if freezeDur:
			global.ON_RUN_FEATURES.freeze_inflict(body, freezeDur)
		if lifeSteal:
			global.PLAYER.stats.currentHP += carryingDamage*lifeSteal
	
	$Sprite2D.visible = false
	collision_mask = 0
	iceFlakes.visible = true
	iceFlakes.emitting = true
	set_process(false)
	iceFlakes.finished.connect(queue_free)


func explode_into_icicles(from: Vector2, icicleAmount: int = 4) -> void:
	var icicleBP: PackedScene = load("res://Scenes/Allies&Summons/icicle.tscn")
	var world: Node2D = global.WORLD
	var d: float = carryingDamage * 0.1
	var kbi: float = carryingKnockBackIntensity * 0.1
	var fd: float = freezeDur * 0.2
	var param: float = TAU / icicleAmount
	for i in range(icicleAmount):
		var icicle: Icicle = icicleBP.instantiate()
		var dir: Vector2 = Vector2.from_angle((i+1) * param)
		icicle.global_position = from
		icicle.setup(dir, d, carryingDamageType, kbi, fd, lifeSteal, toExplode)
		world.add_child.call_deferred(icicle)
	
	queue_free()


func _process(delta: float) -> void:
	var deltaDist: Vector2 = goingTowards * SPEED * delta
	position += deltaDist
	
	travelledDisSq += deltaDist.length_squared()
	if travelledDisSq > 4000000.0:
		queue_free()
