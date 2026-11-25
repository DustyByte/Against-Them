shader_type canvas_item;
// The Wisp's laser beam, drawn on one stretched quad (Scripts/laser_orb.gd).
// UV.x runs along the beam, UV.y across it (0.5 = centre). The quad starts
// cap_px behind the eye, so the beam begins in a soft round cap.
//  - layers: a white-hot core, a crimson glow and a faint wide haze
//  - a living edge: thickness flicker and a heat-haze shimmer racing outwards
//  - charge: a thin dashed aiming thread runs out to the target first
//  - fade: the beam breaks into tapering pieces that shed embers
//  - Eliminate: level widens and brightens it; a pulse rides down the beam

uniform float length_px = 1500.0;
uniform float height_px = 90.0;
uniform float width_px = 15.0;      // glow width at full power, level 1
uniform float level = 1.0;          // Eliminate: 1 -> full width (set by laser_orb.gd)
uniform float charge = 0.0;         // 0 -> 1 while charging (aiming thread)
uniform float power = 0.0;          // 0 -> 1 beam on
uniform float fade = 0.0;           // 0 -> 1 beam dying
uniform float pulse = -1.0;         // 0 -> 1 position of an Eliminate pulse, -1 none
uniform float cap_px = 70.0;        // the quad starts this far behind the eye (round start)
uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.94, 1.0);
uniform vec4 glow_color : source_color = vec4(0.93, 0.27, 0.33, 1.0);
uniform vec4 haze_color : source_color = vec4(0.75, 0.16, 0.26, 1.0);

float hash(float n) { return fract(sin(n * 127.1 + 31.7) * 43758.5453); }
float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	float along = UV.x * length_px - cap_px;        // px from the eye (negative behind it)
	float across = (UV.y - 0.5) * height_px;        // px from the centre line
	vec3 col = vec3(0.0);
	float alpha = 0.0;

	// --- aiming thread while charging ---
	if (charge > 0.0 && power <= 0.0) {
		float reach = charge * length_px * 0.6;
		float thread = (1.0 - smoothstep(0.9, 2.2, abs(across))) * step(along, reach) * step(0.0, along);
		thread *= 0.35 + 0.65 * step(0.5, fract(along / 26.0 - TIME * 60.0));   // dashed, racing out
		thread *= 1.0 - along / max(reach, 1.0) * 0.6;
		col += mix(glow_color.rgb, core_color.rgb, 0.4) * 1.4 * thread;
		alpha += thread * 0.9 * charge;
	}

	if (power > 0.0) {
		// thickness: power, Eliminate level and a quick flicker
		float flicker = 1.0 + 0.07 * sin(TIME * 41.0) + 0.05 * sin(TIME * 67.0 + along * 0.01);
		float w = width_px * level * power * flicker * (1.0 - fade * 0.85);
		// fade: the beam breaks into pieces. Each piece tapers to a point at its
		// ends (its width shrinks with the mask) instead of being cut off square.
		float pieces = 1.0;
		if (fade > 0.0) {
			pieces = smoothstep(fade - 0.3, fade + 0.3, vnoise(along * 0.05 + 3.0));
			w *= max(pieces, 0.001);
		}
		// heat-haze shimmer: the edge wobbles along the beam
		float shimmer = (vnoise(along * 0.05 - TIME * 110.0) - 0.5) * w * 0.35;   // races outwards (~2200 px/s)
		float d = abs(across + shimmer * smoothstep(0.0, w, abs(across)));
		// behind the eye the beam ends in a soft round cap instead of a straight cut
		if (along < 0.0) {
			d = length(vec2(along * 1.6, d));
		}
		float core = exp(-pow(d / (w * 0.16 + 0.6), 2.0));
		float glow = exp(-pow(d / (w * 0.5), 2.0));
		float haze = exp(-pow(d / (w * 1.4), 2.0)) * 0.5;
		// everything eases to nothing before the quad's edge, so the glow is never cut off
		float edge = (1.0 - smoothstep(height_px * 0.3, height_px * 0.5, abs(across)))
				* smoothstep(-cap_px, -cap_px * 0.4, along);   // and before the quad's start
		glow *= edge;
		haze *= edge;
		// longer held beams (higher level) burn steadier and brighter
		float bright = 0.85 + 0.15 * min(level, 3.0);
		// Eliminate pulse: a bright, swollen band travelling down the beam
		float p = 0.0;
		if (pulse >= 0.0) {
			p = exp(-pow((UV.x - pulse) * length_px / 40.0, 2.0)) * (1.0 - pulse * 0.5);
			glow *= 1.0 + 1.5 * p;
			haze *= 1.0 + 2.0 * p;
		}
		// the beam gets fainter far from the wisp
		float reach_fade = 1.0 - smoothstep(0.55, 1.0, UV.x);
		col += core_color.rgb * core * 1.4 + glow_color.rgb * glow * bright + haze_color.rgb * haze;
		alpha += clamp(core + glow * 0.9 + haze, 0.0, 1.0) * smoothstep(0.0, 0.35, pieces) * reach_fade;

		// embers shed as it dies: specks drifting out sideways from the beam
		if (fade > 0.0) {
			for (int i = 0; i < 14; i++) {
				float fi = float(i);
				float x = hash(fi) * 0.55 * length_px;
				float side = hash(fi + 7.0) < 0.5 ? -1.0 : 1.0;
				float y = side * (w * 0.3 + fade * height_px * (0.15 + 0.25 * hash(fi + 3.0)));
				float r = mix(2.2, 0.6, fade);
				float e = 1.0 - smoothstep(r * 0.3, r, length(vec2(along - x - fade * 20.0 * hash(fi + 5.0), across - y)));
				col += mix(core_color.rgb, glow_color.rgb, fade) * e * 1.2;
				alpha += e * (1.0 - fade);
			}
		}
	}
	COLOR = vec4(col / max(alpha, 0.001), clamp(alpha, 0.0, 1.0));
}
