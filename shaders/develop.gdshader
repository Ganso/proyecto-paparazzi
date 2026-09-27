shader_type canvas_item;

uniform float coc_pixels = 0.0;
uniform float exposure = 0.0;
uniform vec2 motion = vec2(0.0);
uniform vec2 shake = vec2(0.0);
uniform float grain = 0.0;
uniform float shot_seed = 0.0;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.38;
uniform float chromatic_aberration : hint_range(0.0, 1.0) = 0.28;

float random(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + shot_seed) * 43758.5453);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 uv_norm = UV - vec2(0.5);
	float r2 = dot(uv_norm * vec2(1.0, 0.5625), uv_norm * vec2(1.0, 0.5625));
	vec2 ca_dir = uv_norm * r2 * 0.015 * chromatic_aberration;

	vec3 color = vec3(0.0);
	for (int i = 0; i < 17; i++) {
		float t = float(i) / 16.0 - 0.5;
		float a = float(i) * 2.399963;
		vec2 blur = vec2(cos(a), sin(a)) * sqrt(float(i) / 16.0) * coc_pixels;
		vec2 base_uv = UV + px * (blur + t * motion + sin(float(i) * 1.7) * shake);

		float r = texture(TEXTURE, clamp(base_uv + ca_dir, vec2(0.0), vec2(1.0))).r;
		float g = texture(TEXTURE, clamp(base_uv, vec2(0.0), vec2(1.0))).g;
		float b = texture(TEXTURE, clamp(base_uv - ca_dir, vec2(0.0), vec2(1.0))).b;
		color += vec3(r, g, b);
	}
	color /= 17.0;

	// Exposure compensation
	color = pow(max(color, vec3(0.0)), vec3(1.0 + clamp(exposure, -3.0, 3.0) * 0.06)) * exp2(-exposure);

	// Optical lens vignetting (natural cos^4 falloff simulation)
	float vig = clamp(1.0 - r2 * 2.4 * vignette_amount, 0.0, 1.0);
	vig = smoothstep(0.0, 1.0, vig);
	color *= mix(0.70, 1.0, vig);

	// Analog grain with luminance weighting
	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	float grain_weight = clamp(1.0 - abs(lum - 0.45) * 1.6, 0.25, 1.0);
	color += (random(UV) - 0.5) * grain * grain_weight;

	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
