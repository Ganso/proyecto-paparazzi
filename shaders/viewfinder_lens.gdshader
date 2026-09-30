// Lens character of the viewfinder (docs/futuro/17 postprocesado): natural vignetting and lateral
// chromatic aberration that grow with wide angles, drawn on the SubViewportContainer. It only
// changes colour, never geometry, so AF points and projections stay aligned with the HUD.
// The developed photo uses the same strengths (develop.gdshader: vignette_amount, chromatic_aberration).
shader_type canvas_item;

uniform float vignette_amount : hint_range(0.0, 1.0) = 0.38;
uniform float chromatic_aberration : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	vec2 centred = UV - vec2(0.5);
	float r2 = dot(centred * vec2(1.0, 0.5625), centred * vec2(1.0, 0.5625));
	vec2 shift = centred * r2 * 0.015 * chromatic_aberration;
	vec3 color = vec3(texture(TEXTURE, UV + shift).r, texture(TEXTURE, UV).g, texture(TEXTURE, UV - shift).b);
	float vignette = smoothstep(0.0, 1.0, clamp(1.0 - r2 * 2.4 * vignette_amount, 0.0, 1.0));
	COLOR = vec4(color * mix(0.70, 1.0, vignette), 1.0);
}
