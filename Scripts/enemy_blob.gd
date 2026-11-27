class_name EnemyBlob
extends Node2D

## The round blob enemy 7 spits at Echo. It sets off slowly along the line to
## where Echo stood and keeps speeding up a little, so it can be outrun early
## and dodged sideways. It hurts Echo on touch and is gone after LIFETIME.
## Drawn once with _draw (no texture); it wobbles by scaling.

const START_SPEED: float = 90.0
const ACCELERATION: float = 70.0   # px/s added every second
const MAX_SPEED: float = 380.0
const RADIUS: float = 11.0
## How close to Echo's middle counts as a hit.
const HIT_DISTANCE: float = 28.0
## Echo's middle, relative to Echo's position.
const PLAYER_CENTRE_OFFSET: Vector2 = Vector2(0, -20)
const LIFETIME: float = 7.0
const OUTER: Color = Color(0.36, 0.52, 0.12)
const INNER: Color = Color(0.64, 0.80, 0.22)
const SHINE: Color = Color(0.88, 0.96, 0.62, 0.9)

var damage: float = 10.0
var _direction: Vector2 = Vector2.RIGHT
var _speed: float = START_SPEED
var _age: float = 0.0


func launch(from: Vector2, target: Vector2, hitDamage: float) -> void:
	global_position = from
	_direction = from.direction_to(target)
	damage = hitDamage


func _ready() -> void:
	z_index = 2


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, OUTER)
	draw_circle(Vector2(-1.5, -1.5), RADIUS * 0.72, INNER)
	draw_circle(Vector2(-4.0, -4.5), RADIUS * 0.25, SHINE)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	_speed = minf(_speed + ACCELERATION * delta, MAX_SPEED)
	global_position += _direction * _speed * delta
	var wobble: float = sin(_age * 14.0) * 0.08
	scale = Vector2(1.0 + wobble, 1.0 - wobble)

	var player: CharacterBody2D = global.PLAYER
	if is_instance_valid(player) and global_position.distance_squared_to(player.global_position + PLAYER_CENTRE_OFFSET) < HIT_DISTANCE * HIT_DISTANCE:
		if player.get_hit(damage, global_position) <= 0.0:
			player.handle_death()
		queue_free()
