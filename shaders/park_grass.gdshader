// Grass swaying in the wind (docs/futuro/17 fase 5, hd only). Instanced tufts of curved blades;
// the sway grows with the height of each vertex (UV.y: 0 at the root, 1 at the tip) and gusts
// travel across the park. INSTANCE colour carries the tint of each tuft.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 root_color : source_color = vec3(0.16, 0.30, 0.08);
uniform vec3 tip_color : source_color = vec3(0.52, 0.66, 0.25);
uniform vec2 wind_direction = vec2(0.8, 0.6);
uniform float wind_strength = 0.05;
uniform float gust_scale = 0.07;

varying float tip;
varying vec3 tint;

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
	tip = UV.y;
	tint = COLOR.rgb;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 dir = normalize(wind_direction);
	// Gusts: a slow noise field drifting downwind, plus a quick flutter per tuft.
	float gust = noise(world.xz * gust_scale - dir * TIME * 0.6);
	float flutter = sin(TIME * 3.1 + dot(world.xz, vec2(1.7, 2.3)) * 2.0) * 0.25;
	float bend = wind_strength * (0.35 + gust * 1.3 + flutter) * tip * tip;
	vec3 offset = vec3(dir.x, 0.0, dir.y) * bend;
	// Keep the blade length roughly constant: bending lowers the tip.
	offset.y = -bend * bend * 2.0;
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * offset);
	// Normals leaning up: the tufts take the light like the lawn under them.
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.7));
}

void fragment() {
	ALBEDO = mix(root_color, tip_color, tip) * tint;
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.25, 0.3, 0.1) * tip;
	AO = mix(0.55, 1.0, tip);
}
