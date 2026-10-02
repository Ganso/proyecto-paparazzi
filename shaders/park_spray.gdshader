// Falling water of the fountain (docs/futuro/17): the curtains of the two bowls as separate
// threads that break into drops on the way down, matt white like aerated water, and a foam ring
// at the foot. The jet on top is made of drops (park.gd::add_fountain_jet(), CPUParticles3D).
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
	float y = world_position.y;
	// How far down its curtain this point is (0 at the bowl's lip, 1 at the foot): the upper
	// curtain falls from 1.66 to 0.99 m, the lower one from 0.96 to 0.22 m.
	float fall = y > 0.975 ? (1.66 - y) / 0.67 : (0.96 - y) / 0.74;
	fall = clamp(fall, 0.0, 1.0);
	// Separate threads of water (thin along the angle, long along the fall), not a sheet: between
	// them the curtain is empty. They speed up and break into drops as they fall.
	float around = angle * (radius * 26.0 + 18.0);
	// Free fall: the water has travelled a distance that grows with the square of the time since it
	// left the lip, so the pattern runs on sqrt(fall) minus time: it moves down, ever faster.
	// (Scaling time by the fall instead made it creep upwards in slow motion.)
	float travel = sqrt(fall) - TIME * 2.4;
	float threads = smoothstep(0.52, 0.72, noise(vec2(around, travel * 2.2)));
	float drops = smoothstep(0.38, 0.62, noise(vec2(around * 1.4, travel * 11.0)));
	float body = threads * mix(1.0, drops, fall * 0.85);
	// A continuous lip where the water leaves the bowl, thinning at once.
	float lip = smoothstep(0.12, 0.0, fall) * 0.75;
	// Foam band: the flat ring on the pond surface.
	float foam = smoothstep(0.3, 0.22, y) * (0.6 + 0.4 * noise(offset * 18.0 + TIME * 1.5));
	// White, matt water (aerated): no mirror highlight, which is what made it look like glass.
	ALBEDO = mix(water_color, vec3(1.0), 0.35);
	EMISSION = water_color * 0.16;
	ROUGHNESS = 0.65;
	SPECULAR = 0.25;
	ALPHA = clamp(max(body * (0.85 - 0.3 * fall), lip) + foam * 0.7, 0.0, 0.95);
}
