// Main menu: the live park seen through a block of translucent white glass (docs/futuro/20).
// Blurs what is behind (screen texture mip levels), washes it towards a cool white and adds soft
// sky-blue glows; brighter on the left, where the menu sits, so the text stays readable.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 1.6;
uniform float wash = 0.34;
uniform float time_scale = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 behind = textureLod(screen_texture, uv, blur_lod).rgb * 0.6
		+ textureLod(screen_texture, uv + vec2(0.004, 0.003), blur_lod + 0.8).rgb * 0.4;
	// Stronger wash behind the menu column (left), lighter towards the right.
	float side = smoothstep(0.78, 0.12, uv.x);
	vec3 white = vec3(0.965, 0.98, 1.0);
	vec3 color = mix(behind, white, wash + side * 0.42);
	// Sky-blue light blooms drifting slowly in the glass.
	float t = TIME * 0.05 * time_scale;
	vec2 c1 = vec2(0.82 + sin(t) * 0.05, 0.22 + cos(t * 1.3) * 0.04);
	vec2 c2 = vec2(0.18 + cos(t * 0.8) * 0.04, 0.92);
	vec2 aspect = vec2(1.0, 0.5625);
	float g1 = exp(-dot((uv - c1) / aspect * 0.55, (uv - c1) / aspect * 0.55) * 9.0);
	float g2 = exp(-dot((uv - c2) / aspect * 0.55, (uv - c2) / aspect * 0.55) * 7.0);
	color += vec3(0.42, 0.72, 1.0) * (g1 * 0.22 + g2 * 0.14);
	// Fine frost grain.
	float n = fract(sin(dot(floor(FRAGCOORD.xy * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
	color += (n - 0.5) * 0.012;
	COLOR = vec4(color, 1.0);
}
