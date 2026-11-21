extends SceneTree
# Bakes each boulder SVG in Assets/Source into its PNG in Assets/World Objects:
# a soft contact shadow is drawn in (the SVG blur does not import), it is
# rendered at 0.8 scale and cropped. Run it after editing an SVG:
#   godot --headless --path . -s Tools/bake_boulder.gd
# If an art changes size or shape, update its FOOT below and, in boulder.gd,
# its row of SPRITE_OFFSETS (printed as foot px), ART_RECTS (printed),
# FOOT_OUTLINES, BLADE_SPOTS and CLEAR_OVALS.
const SCALE := 0.8
const PAD := 16
const SHADOW := Color("#03141f")
# Per boulder: source, output, shadows in SVG units (centre, radii, opacity),
# and FOOT, the footprint centre in SVG units (its sort anchor).
const BOULDERS := [
	{
		"svg": "res://Assets/Source/boulder01.svg",
		"png": "res://Assets/World Objects/Boulder01.png",
		"shadows": [[Vector2(268, 330), Vector2(232, 38), 0.6], [Vector2(458, 360), Vector2(58, 12), 0.6]],
		"foot": Vector2(270, 318),
	},
	{
		"svg": "res://Assets/Source/boulder02.svg",
		"png": "res://Assets/World Objects/Boulder02.png",
		"shadows": [[Vector2(240, 368), Vector2(175, 28), 0.6], [Vector2(64, 386), Vector2(44, 10), 0.6], [Vector2(130, 393), Vector2(20, 5), 0.5]],
		"foot": Vector2(230, 320),
	},
	{
		"svg": "res://Assets/Source/boulder04.svg",
		"png": "res://Assets/World Objects/Boulder04.png",
		"shadows": [[Vector2(250, 334), Vector2(195, 24), 0.6]],
		"foot": Vector2(250, 312),
	},
]

func _init() -> void:
	for b in BOULDERS:
		_bake(b)
	quit()

func _bake(b: Dictionary) -> void:
	var svg := Image.new()
	svg.load_svg_from_string(FileAccess.get_file_as_string(b.svg), SCALE)
	var w := svg.get_width() + PAD * 2
	var h := svg.get_height() + PAD * 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for s in b.shadows:
		var c: Vector2 = s[0] * SCALE + Vector2(PAD, PAD)
		var r: Vector2 = s[1] * SCALE
		var soft: float = 14.0 * SCALE          # blur reach, px
		var outer: Vector2 = r + Vector2(soft, soft)
		for y in range(maxi(0, int(c.y - outer.y)), mini(h, int(c.y + outer.y) + 1)):
			for x in range(maxi(0, int(c.x - outer.x)), mini(w, int(c.x + outer.x) + 1)):
				# Fade over `soft` px either side of the ellipse's edge, the same
				# width all round, like a blur. (Distance to the edge, from the
				# ellipse equation and its gradient.)
				var q := Vector2(x - c.x, y - c.y)
				var d := Vector2(q.x / r.x, q.y / r.y).length()
				var dist: float = -soft
				if d > 0.001:
					var grad := Vector2(q.x / (r.x * r.x), q.y / (r.y * r.y)) / d
					dist = (d - 1.0) / grad.length()
				var a: float = s[2] * (1.0 - smoothstep(-soft, soft, dist))
				if a > 0.002:
					var old := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(SHADOW.r, SHADOW.g, SHADOW.b, maxf(old.a, a)))
	img.blend_rect(svg, Rect2i(Vector2i.ZERO, svg.get_size()), Vector2i(PAD, PAD))
	var used := img.get_used_rect()
	used = used.grow(1).intersection(Rect2i(0, 0, w, h))
	var out := img.get_region(used)
	out.save_png(b.png)
	var foot: Vector2 = b.foot * SCALE + Vector2(PAD, PAD) - Vector2(used.position)
	var art := Rect2(-foot / SCALE, Vector2(out.get_size()) / SCALE)
	print("BAKED ", b.png.get_file(), " size=", out.get_size(), "  foot(px)=", foot, "  art rect=", art)
