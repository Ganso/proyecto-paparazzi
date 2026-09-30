// Moving water of the fountain (docs/futuro/17 fase 4): the jet rises and the curtains fall as
// streaks of varying thickness scrolling along the flow, with sparkle and a foam ring at the foot.
// `center` is the fountain axis in world xz; the geometry has no UVs, so the pattern uses the
// angle around the axis and the height.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec2 center = vec2(0.0);
uniform vec3 water_color : source_color = vec3(0.82, 0.93, 1.0);

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

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 offset = world_position.xz - center;
	float radius = length(offset);
	// atan(0, 0) is undefined on the axis (NaN on AMD).
	float angle = radius < 1e-5 ? 0.0 : atan(offset.y, offset.x);
	// The central jet (thin, near the axis) rises; the curtains fall.
	float jet = step(radius, 0.12);
	float flow = mix(1.0, -1.4, jet);
	float y = world_position.y;
	vec2 streak_uv = vec2(angle * (radius * 9.0 + 6.0), y * 3.0 + TIME * 2.6 * flow);
	float streaks = noise(vec2(streak_uv.x * 1.0, streak_uv.y * 0.35)) * 0.65 + noise(streak_uv * vec2(2.3, 0.9)) * 0.35;
	float sparkle = smoothstep(0.82, 0.97, noise(streak_uv * vec2(3.0, 2.0) + 11.0));
	// Foam band: the flat ring on the pond surface.
	float foam = smoothstep(0.3, 0.22, y) * (0.6 + 0.4 * noise(offset * 18.0 + TIME * 1.5));
	ALBEDO = water_color;
	EMISSION = water_color * (0.08 + 0.5 * sparkle);
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
	ALPHA = clamp(0.18 + 0.62 * smoothstep(0.35, 0.8, streaks) + 0.3 * sparkle + foam * 0.6, 0.0, 0.95);
}
