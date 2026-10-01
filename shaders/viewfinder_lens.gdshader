// Lens character of the viewfinder (docs/futuro/17 postprocesado): natural vignetting and lateral
// chromatic aberration that grow with wide angles, drawn on the SubViewportContainer. It only
// changes colour, never geometry, so AF points and projections stay aligned with the HUD.
// The developed photo uses the same strengths (develop.gdshader: vignette_amount, chromatic_aberration).
//
// Realistic finders (docs/futuro/07 §1, finder_body ≥ 0; -1 = classic interface):
//   2 réflex       focusing-screen grain (fixed: it is etched glass), a few dust specks, warmer tint
//   1 telemétrica  clean bright glass, slightly cooler; the image shifts with the parallax
//   0 compacta     LCD: visible pixel grid, contrast/saturation of a small screen, noise in dim light
// Like the rest of this shader it only touches what is shown on screen, never the photo.
shader_type canvas_item;

uniform float vignette_amount : hint_range(0.0, 1.0) = 0.38;
uniform float chromatic_aberration : hint_range(0.0, 1.0) = 0.28;
uniform int finder_body = -1;
uniform vec2 parallax = vec2(0.0);
uniform float lcd_noise : hint_range(0.0, 1.0) = 0.0;
uniform bool lens_off = false;   // Bajo: no vignetting or chromatic aberration

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV - parallax;
	vec2 centred = uv - vec2(0.5);
	float r2 = dot(centred * vec2(1.0, 0.5625), centred * vec2(1.0, 0.5625));
	vec2 shift = lens_off ? vec2(0.0) : centred * r2 * 0.015 * chromatic_aberration;
	vec3 color = vec3(texture(TEXTURE, uv + shift).r, texture(TEXTURE, uv).g, texture(TEXTURE, uv - shift).b);
	float vignette = smoothstep(0.0, 1.0, clamp(1.0 - r2 * 2.4 * vignette_amount, 0.0, 1.0));
	if (!lens_off) color *= mix(0.70, 1.0, vignette);
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	if (finder_body == 2) {
		// Ground glass: fine fixed grain, a soft brighter centre (Fresnel lens) and dust specks.
		float grain = hash(floor(px * 0.75)) - 0.5;
		color *= 1.0 + grain * 0.07;
		color *= mix(0.9, 1.04, smoothstep(0.55, 0.0, length(centred * vec2(1.0, 0.5625)) * 1.6));
		vec2 cell = floor(UV * vec2(24.0, 13.5));
		float speck = hash(cell + 7.3);
		if (speck > 0.965) {
			vec2 spot = (vec2(hash(cell + 1.1), hash(cell + 2.2)) + cell) / vec2(24.0, 13.5);
			float d = length((UV - spot) / TEXTURE_PIXEL_SIZE);
			color *= mix(0.55, 1.0, smoothstep(0.6, 2.2 + speck * 6.0 - 5.8, d));
		}
		color *= vec3(1.03, 1.0, 0.95);
	} else if (finder_body == 1) {
		color = mix(color, color * vec3(0.97, 1.0, 1.05), 0.6) * 1.04;
		if (uv.x < 0.0 || uv.y < 0.0) color = vec3(0.03);
	} else if (finder_body == 0) {
		// LCD: pixel grid every 3 screen pixels, punchier contrast, cooler white, noise in the dark.
		vec2 cellp = fract(px / 4.0);
		float grid = (cellp.x < 0.2 || cellp.y < 0.2) ? 0.93 : 1.0;
		color = clamp((color - 0.5) * 1.12 + 0.52, 0.0, 1.0);
		float luma = dot(color, vec3(0.3, 0.59, 0.11));
		color = mix(vec3(luma), color, 1.15) * vec3(0.96, 1.0, 1.06);
		float n = hash(floor(px / 2.0) + fract(TIME * 13.0) * 91.7) - 0.5;
		color += n * lcd_noise * 0.22;
		color *= grid;
	}
	COLOR = vec4(color, 1.0);
}
