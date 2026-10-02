// Water of the pond and the fountain bowls (docs/futuro/17 fase 4). Procedural and animated.
// The pond's sheet is a ring-subdivided mesh that really moves: waves of a couple of centimetres
// spread from where the falling curtain hits it and a slow swell crosses it (vertex()). On top,
// two scrolling noise layers and fine rings ripple the normal, with foam at the impact line.
// `center` is the fountain axis (world xz). The bowls (above 0.6 m) stay flat: only their normal ripples.
shader_type spatial;
render_mode cull_back;

uniform vec2 center = vec2(0.0);
uniform vec3 deep_color : source_color = vec3(0.08, 0.19, 0.22);
uniform vec3 shallow_color : source_color = vec3(0.20, 0.37, 0.40);
uniform vec3 foam_color : source_color = vec3(0.92, 0.97, 1.0);
// Radius at which the lower curtain meets the pond.
uniform float impact_radius = 1.16;

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Height of the water surface, used only for its slope.
float height(vec2 p, float t) {
	float h = noise(p * 3.1 + vec2(t * 0.35, t * 0.22)) * 0.6;
	h += noise(p * 7.3 - vec2(t * 0.5, -t * 0.41)) * 0.3;
	h += noise(p * 17.0 + vec2(-t * 0.9, t * 0.7)) * 0.1;
	float d = length(p - center);
	// Rings travelling outwards from the curtain, fading with distance.
	h += 0.35 * sin(d * 26.0 - t * 5.5) * exp(-abs(d - impact_radius) * 1.6);
	return h;
}

// Real displacement of the pond's surface in metres (± 2 cm: it never leaves its stone rim).
float swell(vec2 p, float t) {
	float d = length(p - center);
	float rings = sin(d * 7.0 - t * 2.6) * exp(-abs(d - impact_radius) * 0.85);
	float wind = sin(p.x * 1.7 + t * 0.9) * sin(p.y * 2.3 - t * 0.7);
	return 0.013 * rings + 0.007 * wind;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (world_position.y < 0.6) {
		float lift = swell(world_position.xz, TIME);
		VERTEX.y += lift;
		world_position.y += lift;
	}
}

void fragment() {
	vec2 p = world_position.xz;
	float t = TIME;
	float e = 0.02;
	float h = height(p, t);
	vec2 slope = vec2(height(p + vec2(e, 0.0), t) - h, height(p + vec2(0.0, e), t) - h) / e;
	// The slope of the moving surface itself lights the big waves.
	vec2 big = world_position.y < 0.6 ? vec2(swell(p + vec2(e, 0.0), t) - swell(p, t), swell(p + vec2(0.0, e), t) - swell(p, t)) / e : vec2(0.0);
	vec3 world_normal = normalize(vec3(-slope.x * 0.035 - big.x, 1.0, -slope.y * 0.035 - big.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	float d = length(p - center);
	float foam = smoothstep(0.35, 0.0, abs(d - impact_radius)) * (0.55 + 0.45 * noise(p * 22.0 + t * 2.0));
	foam = max(foam, smoothstep(0.62, 0.9, noise(p * 9.0 + t * 0.6)) * 0.15);
	// Grazing views see more of the (lighter) reflected sky, steep views see the dark depth.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 water = mix(shallow_color, deep_color, facing);
	ALBEDO = mix(water, foam_color, foam);
	ROUGHNESS = mix(0.04, 0.5, foam);
	SPECULAR = 0.65;
	METALLIC = 0.0;
}
