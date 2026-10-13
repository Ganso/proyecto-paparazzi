shader_type canvas_item;
// The focusing aid of manual focus over the finder: the split image of the ground glass (TLR, SLR)
// and the rangefinder's double image.
//
// As the optics make it (docs/futuro/28): the halves of a split image look at the scene through
// opposite sides of the lens, so what is at the focused distance falls in the same place in both
// and everything else is displaced, **each thing by its own distance from the focus plane**.
// Somebody walking past in front is split; the background the player focused on, behind and
// around them, stays exactly as it was. Only the focusing ring moves what coincides.
//   depth_view      how far every pixel of the zone is (shaders/aid_depth.gdshader), `margin`
//                   times the zone, from the camera's own place
//   focus_dioptres  1 / the distance the ring is set to (0: infinity)
//   gain            displacement (fraction of the width) per dioptre off focus: the scale the aid
//                   always had (0.006 × focal). It is far more than a real lens gives, so that a
//                   misfocus shows on a screen…
//   reach           …and so what is far off focus is not carried right across the zone, which a
//                   real one never does: the displacement eases off towards this much
//   softness        blur of what is off focus, as a fraction of its displacement. 0: the halves
//                   are sharp, as the image in a real prism is (user, 13-10-2026: with 0.3 the
//                   figure in front looked motion-blurred)
// The colours are the finder's own image, as always: with the whole zone at one distance this is
// the old picture, shifted as a whole. Without `optics` (no depth view) it is exactly that, with
// one `offset` for the zone.
uniform float offset = 0.0;
uniform bool optics = false;
uniform sampler2D depth_view : filter_nearest, repeat_disable;
uniform float margin = 1.6;
uniform float focus_dioptres = 0.0;
uniform float gain = 0.3;
uniform float reach = 0.0154;
uniform float softness = 0.5;
uniform int body = 2;
uniform bool mirror = false;   // TLR: the ground glass is seen mirrored

const int STEPS = 64;

vec2 zone_size() {
	return body == 1 ? vec2(0.095, 0.048) : vec2(0.078);
}

// Distance (m) of what the finder's image shows at `at` (its own UV, not mirrored). The nearest of
// the pixel and its four neighbours: the outline of a figure is drawn half figure and half
// background, and that rim has to go with the figure or it stays behind as a fringe.
float distance_at(vec2 at) {
	vec2 q = (at - vec2(0.5)) * vec2(1.777778, 1.0) / (2.0 * zone_size() * margin) + vec2(0.5);
	vec2 px = 1.0 / vec2(textureSize(depth_view, 0));
	float z = texture(depth_view, q).r;
	z = min(z, texture(depth_view, q + vec2(px.x, 0.0)).r);
	z = min(z, texture(depth_view, q - vec2(px.x, 0.0)).r);
	z = min(z, texture(depth_view, q + vec2(0.0, px.y)).r);
	z = min(z, texture(depth_view, q - vec2(0.0, px.y)).r);
	return z * 100.0;
}

float shift_of(float z) {
	float linear = (focus_dioptres - 1.0 / max(z, 0.05)) * gain;
	return reach * tanh(linear / reach);
}

// The finder's image at `at`, softened over a radius (fraction of the width).
vec3 soft(sampler2D image, vec2 at, float radius) {
	if (radius < 0.0003) return texture(image, at).rgb;
	vec3 sum = vec3(0.0);
	float total = 0.0;
	for (int i = -3; i <= 3; i++) {
		for (int j = -3; j <= 3; j++) {
			vec2 d = vec2(float(i), float(j)) / 3.0;
			float w = exp(-dot(d, d) * 2.0);
			sum += texture(image, at + d * radius * vec2(1.0, 1.777778)).rgb * w;
			total += w;
		}
	}
	return sum / total;
}

// What shows at `at` in a half that displaces by `side` (+1 or −1): the point of the scene whose
// own shift brings it there (a point at x shows at x − its shift). Walking across the reach, the
// exact place where «the shift of what is there» equals «how far away it is» is found between two
// samples of the same surface; of several, the nearest surface (it hides the others). Where an
// edge leaves a gap (what was behind the thing displaced), the background beside it goes on.
vec3 displaced(sampler2D image, vec2 at, float side) {
	float step_size = 2.0 * reach / float(STEPS);
	float best_z = 1e9;
	float best_o = 0.0;
	bool found = false;
	float far_z = -1.0;
	float far_o = 0.0;
	float far_way = 0.0;      // which way the background goes on from that edge
	float o0 = -reach;
	float z0 = distance_at(at + vec2(o0, 0.0));
	float s0 = shift_of(z0) * side;
	for (int i = 1; i <= STEPS; i++) {
		float o1 = -reach + step_size * float(i);
		float z1 = distance_at(at + vec2(o1, 0.0));
		float s1 = shift_of(z1) * side;
		float f0 = s0 - o0;
		float f1 = s1 - o1;
		if ((f0 >= 0.0 && f1 <= 0.0) || (f0 <= 0.0 && f1 >= 0.0)) {
			if (abs(s1 - s0) < step_size * 1.5) {
				float t = abs(f0 - f1) < 1e-7 ? 0.5 : f0 / (f0 - f1);
				float z = mix(z0, z1, t);
				if (z < best_z) {
					best_z = z;
					best_o = mix(o0, o1, t);
					found = true;
				}
			} else if (max(z0, z1) > far_z) {
				far_z = max(z0, z1);
				far_o = z0 > z1 ? o0 : o1;
				far_way = z0 > z1 ? -1.0 : 1.0;
			}
		}
		o0 = o1;
		z0 = z1;
		s0 = s1;
	}
	if (found) return soft(image, at + vec2(best_o, 0.0), abs(best_o) * softness);
	// A gap: what was behind the thing displaced is not in the picture. The background beside it
	// goes on, as far past the edge as the gap is from it (stretching the edge itself across the
	// gap drew streaks that read as motion blur); if that falls on something nearer, the edge.
	if (far_z <= 0.0) return texture(image, at).rgb;
	float beyond = far_o + far_way * max(abs(far_o), 3.0 * step_size);
	if (distance_at(at + vec2(beyond, 0.0)) < far_z * 0.8) beyond = far_o + far_way * 3.0 * step_size;
	return soft(image, at + vec2(beyond, 0.0), reach * 0.4);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.777778, 1.0);
	vec2 zone = zone_size();
	bool inside = body == 1 ? abs(p.x) < zone.x && abs(p.y) < zone.y : length(p) < zone.x;
	vec2 uv = UV;
	if (mirror) uv.x = 1.0 - uv.x;
	vec4 c = texture(TEXTURE, uv);
	if (inside) {
		if (body == 1) {
			vec3 ghost = optics ? displaced(TEXTURE, uv, 1.0) : texture(TEXTURE, uv + vec2(offset,0.0)).rgb;
			c.rgb = mix(c.rgb, ghost, 0.5);
			c.rgb *= vec3(1.08,1.03,0.82);
		} else {
			float side = p.y > 0.0 ? 1.0 : -1.0;
			c.rgb = optics ? displaced(TEXTURE, uv, side) : texture(TEXTURE, uv + vec2(side * offset, 0.0)).rgb;
			if (abs(p.y) < 0.001) c.rgb *= 0.3;
		}
	}
	COLOR = vec4(c.rgb, inside ? 1.0 : 0.0);
}
