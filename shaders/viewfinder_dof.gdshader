// Depth of field of the viewfinder (Forward+ Ultra, docs/futuro/02 G14 and 11 §4). Full-screen
// pass that blurs every pixel by its real circle of confusion, with the same formula as
// Photography.coc(): CoC (mm) = f² |z - s| / (N z (s - f)), on a 36 mm wide sensor and converted to
// pixels as develop.gdshader does. The blur never contradicts the aperture chosen by the player.
// Gather with depth ordering: a blurred foreground spreads over sharp background, but a blurred
// background never smears over a sharp subject in front of it.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float focal_mm = 24.0;
uniform float aperture = 5.6;
// Focus distance in metres; a negative value means infinity.
uniform float focus_m = 4.0;
// Largest blur radius in pixels of a 2560 px wide view (scaled to the real width).
uniform float max_radius = 34.0;
uniform bool enabled = true;
// Longitudinal chromatic aberration (0…1, by lens and aperture): green focuses a little behind
// red and blue, so what is blurred in front of the focus plane fringes magenta and what is
// blurred behind it fringes green. Sharp areas are untouched.
uniform float loca = 0.0;

const int TAPS = 64;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Sky and the far plane (depth 0 with Forward+'s reversed z) would give w = 0: an infinite distance
// and a NaN circle of confusion, which the glow blew up into single-frame white flashes.
float linear_depth(vec2 uv, mat4 inv_projection) {
	float depth = texture(depth_texture, uv).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	if (abs(view.w) < 1e-6) return 1e5;
	float z = -view.z / view.w;
	return (z > 0.0 && z < 1e5) ? z : 1e5;
}

// Blur radius in pixels for a point at z metres.
float coc_radius(float z, float width) {
	float zmm = max(z, 0.05) * 1000.0;
	float coc;
	if (focus_m < 0.0) {
		coc = focal_mm * focal_mm / (aperture * zmm);
	} else {
		float s = focus_m * 1000.0;
		coc = focal_mm * focal_mm * abs(zmm - s) / (aperture * zmm * max(s - focal_mm, 1.0));
	}
	return min(coc / 36.0 * width * 0.5, max_radius * width / 2560.0);
}

bool finite(vec3 c) {
	return !(any(isnan(c)) || any(isinf(c)));
}

// This pass runs before tone mapping and glow, so it also repairs the rare non-finite pixel the
// scene produces (thin hat brims seen exactly edge-on): the glow turned each one into a flash.
vec3 safe_sample(vec2 uv, float lod, vec2 size) {
	vec3 c = textureLod(screen_texture, uv, lod).rgb;
	if (finite(c)) return c;
	vec3 sum = vec3(0.0);
	float n = 0.0;
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398;
		vec3 s = textureLod(screen_texture, uv + vec2(cos(a), sin(a)) * 2.0 / size, 0.0).rgb;
		if (finite(s)) { sum += s; n += 1.0; }
	}
	return n > 0.0 ? sum / n : vec3(0.0);
}

void fragment() {
	vec2 size = VIEWPORT_SIZE;
	vec3 base = safe_sample(SCREEN_UV, 0.0, size);
	if (!enabled) {
		ALBEDO = base;
	} else {
		float z0 = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
		float r0 = coc_radius(z0, size.x);
		// Search as far as the largest blur that can reach this pixel: its own, the far background,
		// or a blurred foreground nearby, found with 8 probes at the near-range CoC.
		float search = max(r0, coc_radius(1e5, size.x));
		float probe = coc_radius(0.6, size.x);
		if (probe > search) {
			for (int k = 0; k < 8; k++) {
				float a = float(k) * 0.785398 + 0.39;
				vec2 uv = SCREEN_UV + vec2(cos(a), sin(a)) * probe * 0.7 / size;
				float zp = linear_depth(uv, INV_PROJECTION_MATRIX);
				if (zp < z0) search = max(search, coc_radius(zp, size.x));
			}
		}
		if (search < 0.75) {
			ALBEDO = base;
		} else {
			vec3 sum = base;
			vec3 total = vec3(1.0);
			float focus_z = focus_m < 0.0 ? 1e5 : focus_m;
			float lod = log2(max(1.0, search / 7.0));
			for (int i = 0; i < TAPS; i++) {
				float t = (float(i) + 0.5) / float(TAPS);
				float dist = search * sqrt(t);
				float angle = float(i) * 2.39996323;
				vec2 offset = vec2(cos(angle), sin(angle)) * dist;
				vec2 uv = SCREEN_UV + offset / size;
				float zs = linear_depth(uv, INV_PROJECTION_MATRIX);
				float rs = coc_radius(zs, size.x);
				// In front: its own blur decides. Behind: limited by this pixel's blur.
				float reach = zs < z0 ? rs : min(rs, r0);
				// Behind the focus plane green spreads a little further than red and blue; in front, less.
				float side = (zs > focus_z ? 1.0 : -1.0) * loca * 0.14;
				float w_green = clamp(reach * (1.0 + side) - dist + 1.0, 0.0, 1.0);
				float w_magenta = clamp(reach * (1.0 - side) - dist + 1.0, 0.0, 1.0);
				vec3 w = vec3(w_magenta, w_green, w_magenta);
				vec3 tap = textureLod(screen_texture, uv, lod).rgb;
				sum += (finite(tap) ? tap : base) * w;
				total += w;
			}
			vec3 result = sum / total;
			// Never hand a non-finite value to the glow.
			ALBEDO = (any(isnan(result)) || any(isinf(result))) ? base : result;
		}
	}
}
