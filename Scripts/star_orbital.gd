class_name StarOrbital
extends Node2D

var starBP: PackedScene = preload("res://Scenes/Allies&Summons/star.tscn")
var anomalyBP: PackedScene = preload("res://Scenes/Allies&Summons/anomaly.tscn")
var summonFlags: Node2D = null
var player: CharacterBody2D = null
var stats: Dictionary = {}
var rotationRate: float = 0.0
var radius: float = 100.0
var nowAsBH: bool = false
var currentScaleStar: Vector2 = Vector2.ONE


func add_starand_adjust_position() -> void:
	var star := anomalyBP.instantiate() if nowAsBH else starBP.instantiate()
	if star is Star:
		star.scale = currentScaleStar
		star.setup(stats)
	add_child(star)
	
	var stars: Array = get_children()
	var thetaBetweenEach: float = TAU / stars.size()
	
	for index in range(stars.size()):
		stars[index].position = Vector2.LEFT.rotated(thetaBetweenEach * index) * radius


func update_radius(updatedRadius: float) -> void:
	radius = updatedRadius
	
	for child in get_children():
		if child is Line2D:
			continue
		var direction: Vector2 = child.position.normalized()
		child.position = direction * radius


func collapse_all_stars_into_blackhole() -> void:
	merge_stars_into_blackhole()


## Anomaly: every star races round the orbit to the first star's spot, heating
## up (growing) and speeding up as it goes, and they smash together - a flash,
## a shock ring, a shake - leaving one black hole that orbits like a star did.
const MERGE_TIME: float = 0.6
const IMPACT_RING_RADIUS: float = 95.0

func merge_stars_into_blackhole() -> void:
	nowAsBH = true
	var stars: Array = get_children().filter(func(c): return c is Star)
	if stars.is_empty():
		return
	var meet_angle: float = stars[0].position.angle()
	var tween: Tween = create_tween().set_parallel()
	for star in stars:
		var from_angle: float = star.position.angle()
		var base_scale: Vector2 = star.scale
		tween.tween_method(func(v: float):
			if not is_instance_valid(star):
				return
			var a: float = lerp_angle(from_angle, meet_angle, v)
			star.position = Vector2.from_angle(a) * radius * (1.0 - 0.12 * sin(v * PI))
			star.scale = base_scale * (1.0 + 0.35 * v)
			star.rotation += 0.25 * v,
			0.0, 1.0, MERGE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_on_stars_collided.bind(stars, Vector2.from_angle(meet_angle) * radius))


func _on_stars_collided(stars: Array, at: Vector2) -> void:
	for star in stars:
		if is_instance_valid(star):
			star.queue_free()
	global.activeCamera.shake(9.0)
	global.WORLD.audio_play(preload("res://Assets/SFX/GranularExplosion.wav"), "game_world", 0.6)

	# Shock ring: a circle that bursts out and fades.
	var ring := Line2D.new()
	ring.width = 6.0
	ring.default_color = Color(0.85, 0.75, 1.0, 0.9)
	ring.position = at
	add_child(ring)
	var ring_tween: Tween = create_tween().set_parallel()
	ring_tween.tween_method(func(r: float):
		var points := PackedVector2Array()
		for k in 41:
			points.append(Vector2.from_angle(TAU * k / 40.0) * r)
		ring.points = points,
		8.0, IMPACT_RING_RADIUS, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "width", 0.5, 0.35)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.35)
	ring_tween.chain().tween_callback(ring.queue_free)

	# The black hole: bursts in a little too big, then settles.
	var hole: Node2D = anomalyBP.instantiate()
	hole.position = at
	hole.scale = Vector2.ZERO
	add_child(hole)
	var hole_tween: Tween = create_tween()
	hole_tween.tween_property(hole, "scale", Vector2.ONE * 1.3, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hole_tween.tween_property(hole, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)


func increase_all_star_size(mult: float) -> void:
	var stars: Array = get_children().filter(func(c): return not c is Line2D)
	var dir: Vector2
	radius += 0.0 if nowAsBH else 7.0
	currentScaleStar = stars[0].scale * mult
	for star in stars:
		star.scale = currentScaleStar
		dir = star.position.normalized()
		star.position = dir * radius


func _ready() -> void:
	player = $'..'
	summonFlags = $'..'/SummonFlags
	
	stats = player.stats.activeModifiers.starStats
	
	summonFlags.outerMostOrbitalRadiusChanged.connect(update_radius)
	radius = summonFlags.currentOuterMostOrbitalRadius


func _process(delta: float) -> void:
	rotation += delta / stats.cd
