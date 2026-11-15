class_name UmbraTouch
extends Node2D

## Home screen: touching Umbra. A tap on the oceans sends ripples across the
## surface; a tap on land kicks up a little splash of grass and dust.
##
## The surface part (ripples, dust ring) is drawn by the planet's own shader
## (planet_shade.gdshader) from the touches passed in here. The grass blades
## are drawn by this node: each one flies in 3D around the unit sphere, falls
## back towards its centre and is shown with the planet's orthographic view,
## so blades near the edge are foreshortened and ones behind the globe hide.
##
## Costs nothing while idle: _process only runs while a touch is playing.

const MAX_TOUCHES: int = 6            # as in the shader
const RIPPLE_LIFE: float = 1.8        # as in the shader
const DUST_LIFE: float = 0.7
const EDGE_LIMIT: float = 0.96        # ignore taps on the very rim
const MASK_SIZE: int = 256

const BLADES_PER_SPLASH: int = 11
const SPECKS_PER_SPLASH: int = 6
const GRAVITY: float = 1.7            # planet radii / s^2
const BLADE_COLOR := Color(0.2, 0.55, 0.5)
const BLADE_TIP_COLOR := Color(0.45, 0.8, 0.68)
const SPECK_COLOR := Color(0.3, 0.45, 0.42)

var planet: Sprite2D = null
## Planet radius on screen, in pixels.
var radius: float = 100.0
## Same as the shader's light_dir, so the blades are lit like the planet.
var lightDir := Vector2(0.55, -0.85).normalized()

var _mask: Image = null
var _touches: Array = []      # [disc point: Vector2, age: float, land: bool]
var _bits: Array = []         # [pos: Vector3, vel: Vector3, age: float, life: float, blade: bool, spin: float, length: float]
var _material: ShaderMaterial
var _discRadius: float = 0.455


## A planet shader setting: the material's value, or the shader's default
## when the material leaves it unset.
func _shader_value(param: StringName) -> Variant:
	var v = _material.get_shader_parameter(param)
	if v == null:
		v = RenderingServer.shader_get_parameter_default(_material.shader.get_rid(), param)
	return v


func setup(planetSprite: Sprite2D) -> void:
	planet = planetSprite
	_material = planet.material
	_material.set_shader_parameter("touch_count", 0)
	var l = _shader_value("light_dir")
	if l is Vector2 and l != Vector2.ZERO:
		lightDir = l.normalized()
	_discRadius = _shader_value("disc_radius")
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if planet == null or not (event is InputEventScreenTouch and event.pressed):
		return
	if get_parent().get("_is_leaving"):
		return
	var p: Vector2 = (event.position - planet.global_position) / radius
	if p.length() > EDGE_LIMIT:
		return
	_add_touch(p, _is_land(p))


## True if the disc point (-1..1) is land in the planet art.
func _is_land(p: Vector2) -> bool:
	if _mask == null:
		_build_mask()
	var uv: Vector2 = Vector2(0.5, 0.5) + p * _discRadius
	var px := Vector2i((uv * MASK_SIZE).floor()).clamp(Vector2i.ZERO, Vector2i(MASK_SIZE - 1, MASK_SIZE - 1))
	return _mask.get_pixelv(px).b < 0.36   # the oceans are light blue, land dark navy


## A small copy of the planet art to look up land and water. Made on the
## first tap; about 256 KB.
func _build_mask() -> void:
	_mask = planet.texture.get_image()
	if _mask.is_compressed():
		_mask.decompress()
	_mask.resize(MASK_SIZE, MASK_SIZE, Image.INTERPOLATE_BILINEAR)


func _add_touch(p: Vector2, land: bool) -> void:
	if _touches.size() >= MAX_TOUCHES:
		_touches.pop_front()
	_touches.append([p, 0.0, land])
	if land:
		_spawn_splash(p)
	set_process(true)


func _spawn_splash(p: Vector2) -> void:
	var n := Vector3(p.x, p.y, sqrt(maxf(1.0 - p.length_squared(), 0.0)))
	# Two directions along the surface at the spot.
	var t1: Vector3 = n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var t2: Vector3 = n.cross(t1)
	var start: Vector3 = n * 1.002
	for i in BLADES_PER_SPLASH + SPECKS_PER_SPLASH:
		var blade: bool = i < BLADES_PER_SPLASH
		var a: float = randf() * TAU
		var side: Vector3 = (t1 * cos(a) + t2 * sin(a)) * randf_range(0.07, 0.2)
		var up: float = randf_range(0.26, 0.42) if blade else randf_range(0.16, 0.3)
		_bits.append([start, n * up + side, 0.0, 0.0,
			blade, randf_range(-14.0, 14.0), randf_range(0.018, 0.028)])


func _process(delta: float) -> void:
	planet_follow()
	var i: int = _touches.size() - 1
	while i >= 0:
		var t: Array = _touches[i]
		t[1] += delta
		if t[1] > (DUST_LIFE if t[2] else RIPPLE_LIFE):
			_touches.remove_at(i)
		i -= 1

	i = _bits.size() - 1
	while i >= 0:
		var b: Array = _bits[i]
		var pos: Vector3 = b[0]
		b[2] += delta
		if pos.length() > 1.0:
			# In the air: pulled back towards the planet's centre.
			var vel: Vector3 = b[1]
			vel -= pos.normalized() * GRAVITY * delta
			b[1] = vel
			pos += vel * delta
			if pos.length() <= 1.0:
				pos = pos.normalized()   # landed; lies on the surface and fades
				b[3] = 0.0
			b[0] = pos
		else:
			b[3] += delta
		if b[3] > 0.35:
			_bits.remove_at(i)
		i -= 1

	var data := PackedVector4Array()
	data.resize(MAX_TOUCHES)
	for k in _touches.size():
		var t: Array = _touches[k]
		data[k] = Vector4(t[0].x, t[0].y, t[1], 1.0 if t[2] else 0.0)
	_material.set_shader_parameter("touches", data)
	_material.set_shader_parameter("touch_count", _touches.size())
	queue_redraw()
	if _touches.is_empty() and _bits.is_empty():
		set_process(false)


func planet_follow() -> void:
	position = planet.position


func _draw() -> void:
	var l3 := Vector3(lightDir.x, lightDir.y, 0.6).normalized()
	for b in _bits:
		var pos: Vector3 = b[0]
		var vel: Vector3 = b[1]
		var n: Vector3 = pos.normalized()
		# Behind the globe: hidden.
		if pos.z < 0.0 and Vector2(pos.x, pos.y).length() < 1.0:
			continue
		var landed: float = b[3]
		var alpha: float = 1.0 - landed / 0.35
		# Lit like the planet: bright facing the light, dim on the night side.
		var light: float = lerpf(0.5, 1.0, clampf(n.dot(l3) * 0.5 + 0.5, 0.0, 1.0))
		var at: Vector2 = Vector2(pos.x, pos.y) * radius
		if b[4]:
			# A grass blade: a short sliver tumbling as it flies, shown in
			# 3D so it shortens when it points towards the viewer.
			var ang: float = b[5] * b[2]
			var tangent: Vector3 = vel - n * vel.dot(n)
			if tangent.length_squared() < 1e-6:
				tangent = Vector3(1, 0, 0)
			var axis: Vector3 = (n * cos(ang) + tangent.normalized() * sin(ang)) * b[6]
			var tip: Vector2 = at + Vector2(axis.x, axis.y) * radius
			var base := BLADE_COLOR * light
			var top := BLADE_TIP_COLOR * light
			base.a = alpha
			top.a = alpha
			# Tapered: wide at the root, a point at the tip.
			var side: Vector2 = (tip - at).orthogonal().normalized() * 1.6
			if side == Vector2.ZERO:
				side = Vector2(1.6, 0.0)
			draw_primitive(PackedVector2Array([at - side, at + side, tip]),
				PackedColorArray([base, base, top]), PackedVector2Array())
		else:
			var c := SPECK_COLOR * light
			c.a = alpha * 0.9
			draw_circle(at, 1.4, c)
