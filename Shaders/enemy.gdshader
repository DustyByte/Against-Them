shader_type canvas_item;

// Shared by every enemy part: one material (Material/enemy.tres, or
// enemy_boss.tres for bosses) and one texture (Assets/Enemies/EnemyAtlas.png),
// so the renderer can draw all enemies in a few batches instead of one draw per
// sprite.
//
// It also does the body bob that enemies 1 and 4 used to animate with their
// own AnimationPlayer. A part is recognised by the atlas region it shows (the
// rects below are in atlas pixels: x, y, width, height); keep them in sync with
// the atlas if it is ever rebuilt. Enemy 6 still uses its AnimationPlayer.
//
// enemy_time is advanced by world.gd and stops while the game is paused. Each
// enemy stores its own phase (0..1) once in its Wrapper's modulate.r, read in
// vertex() and then reset to white.

global uniform float enemy_time;
uniform bool outline = false;   // boss outline
uniform vec4 outline_color : source_color = vec4(1.0, 0.47, 0.47, 1.0);

const vec2 ATLAS_SIZE = vec2(512.0, 288.0);
const vec4 E1_HEAD = vec4(317.0, 4.0, 99.0, 95.0);
const vec4 E1_TENTACLES = vec4(4.0, 4.0, 91.0, 156.0);
const vec4 E4_BODY = vec4(4.0, 164.0, 86.0, 70.0);
const vec4 E4_HEAD = vec4(420.0, 4.0, 85.0, 95.0);

varying float outlined;   // 1 on the parts a boss gets an outline on

bool shows(vec2 px, vec4 r) {
	return px.x > r.x - 1.0 && px.y > r.y - 1.0 && px.x < r.x + r.z + 1.0 && px.y < r.y + r.w + 1.0;
}

// 0 -> 1 -> 0 over one cycle, linear like the old keyframes.
float bob(float cycles) {
	return 1.0 - abs(1.0 - 2.0 * fract(cycles));
}

void vertex() {
	float phase = COLOR.r;
	COLOR.rgb = vec3(1.0);
	outlined = 0.0;
	vec2 px = UV * ATLAS_SIZE;
	// Each part moves by the difference from its rest pose (the scene position)
	// and is squashed around its centre, as its keyframes did.
	if (shows(px, E1_HEAD)) {              // enemy 1: 1 s cycle
		float k = bob(enemy_time + phase);
		VERTEX.y = VERTEX.y * (1.0 - 0.125 * k) + 3.75 * k;
		outlined = 1.0;
	} else if (shows(px, E1_TENTACLES)) {
		VERTEX.y -= 18.25 * bob(enemy_time + phase);
	} else if (shows(px, E4_BODY)) {       // enemy 4: 0.8 s cycle, in step with its hops
		float k = bob(enemy_time / 0.8 + phase);
		VERTEX.y = VERTEX.y * (1.0 - 0.18309 * k) - 6.62486 * k;
		outlined = 1.0;
	} else if (shows(px, E4_HEAD)) {
		float k = bob(enemy_time / 0.8 + phase);
		VERTEX.y = VERTEX.y * (1.0 - 0.10443 * k) + 7.0 * k;
		outlined = 1.0;
	}
}

void fragment() {
	// COLOR arrives as the texture colour times the vertex colour.
	if (outline && outlined > 0.5 && COLOR.a == 0.0) {
		vec2 s = TEXTURE_PIXEL_SIZE;
		float around = texture(TEXTURE, UV + vec2(0.0, -s.y)).a + texture(TEXTURE, UV + vec2(0.0, s.y)).a
			+ texture(TEXTURE, UV + vec2(-s.x, 0.0)).a + texture(TEXTURE, UV + vec2(s.x, 0.0)).a;
		if (around > 0.0) {
			COLOR = outline_color;
		}
	}
}
