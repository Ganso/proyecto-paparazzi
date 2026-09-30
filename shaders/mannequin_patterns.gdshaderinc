// Procedural surface patterns of the hd mannequins (docs/futuro/17 fase 5), shared by the toon
// shader (cel_shading) and the realistic one (mannequin_pbr). UV/UV2 carry the position in the
// bone's own space and UV2.y = zone * 100 + bone; the pattern only tints the albedo.
varying vec3 part_position;
varying flat float zone;
varying flat float part;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), u.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), u.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), u.x), u.y), u.z);
}

// Angle around the bone axis. atan(0, 0) is undefined in GLSL (NaN on AMD): on the axis itself
// (the poles of sleeve, hand and head caps) a single NaN pixel became a white flash in the glow.
float axis_angle(vec3 p) {
	return length(p.xz) < 1e-5 ? 0.0 : atan(p.x, p.z);
}

float fbm(vec3 p) {
	return noise(p) * 0.55 + noise(p * 2.1) * 0.28 + noise(p * 4.3) * 0.17;
}

// Albedo factor of the surface pattern for each zone. `coarse` and `fine` fade the large and the
// small features separately, so nothing finer than about two pixels is ever drawn (no shimmer).
float pattern(vec3 p, float z, float seed, float coarse, float fine) {
	if (z < 0.5) {
		// Wood: growth rings around the limb axis (bones point along y), warped by noise, plus fibres.
		vec3 q = p + vec3(seed * 1.7, seed * 3.1, seed * 0.9);
		float r = length(q.xz + vec2(0.02 * seed, 0.0)) * 55.0 + fbm(q * vec3(9.0, 2.0, 9.0)) * 3.0 + q.y * 1.5;
		float rings = smoothstep(0.0, 0.35, fract(r)) * smoothstep(1.0, 0.65, fract(r));
		float fibres = noise(vec3(q.x * 220.0, q.y * 14.0, q.z * 220.0));
		return mix(1.0, mix(0.84, 1.05, rings), coarse) * mix(1.0, mix(0.95, 1.03, fibres), fine);
	} else if (z < 1.5) {
		// Knit (shirts and jackets): ~3 mm loops, soft fuzz and mottling.
		float u = axis_angle(p) * 0.06 * 900.0;
		float v = p.y * 900.0;
		float loops = abs(sin(u + sin(v) * 0.5)) * (0.7 + 0.3 * abs(sin(v * 0.5)));
		float fuzz = fbm(p * 80.0);
		return mix(1.0, mix(0.9, 1.06, fuzz), coarse) * mix(1.0, mix(0.95, 1.02, loops), fine);
	} else if (z < 2.5) {
		// Twill (trousers and skirts): diagonal ribs like denim, with worn mottling.
		float u = axis_angle(p) * 0.07;
		float ribs = 0.5 + 0.5 * sin((u + p.y) * 700.0);
		float wear = fbm(p * vec3(18.0, 6.0, 18.0));
		return mix(1.0, mix(0.86, 1.1, wear), coarse) * mix(1.0, mix(0.94, 1.03, ribs), fine);
	} else if (z < 3.5) {
		// Hair: strands flowing down the head.
		float strands = noise(vec3(axis_angle(p) * 38.0, p.y * 6.0, seed));
		return mix(1.0, mix(0.82, 1.1, strands), coarse);
	}
	return mix(1.0, mix(0.95, 1.03, fbm(p * 90.0)), coarse);
}

void vertex() {
	part_position = vec3(UV.x, UV.y, UV2.x);
	zone = floor(UV2.y / 100.0 + 0.001);
	part = UV2.y - zone * 100.0;
}


// Periods in metres of the coarse and fine features of each zone, faded before they alias.
vec3 textured_albedo(vec3 albedo, float strength) {
	float pixel = length(fwidth(part_position));
	vec2 period = zone < 0.5 ? vec2(0.018, 0.0045) : (zone < 1.5 ? vec2(0.012, 0.007) : (zone < 2.5 ? vec2(0.05, 0.009) : vec2(0.012, 0.012)));
	float coarse = strength * (1.0 - smoothstep(0.2 * period.x, 0.5 * period.x, pixel));
	float fine = strength * (1.0 - smoothstep(0.2 * period.y, 0.5 * period.y, pixel));
	return albedo * pattern(part_position, zone, part, coarse, fine);
}
