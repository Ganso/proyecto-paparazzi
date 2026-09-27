// Toon shading for the wooden mannequins (docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md, 3.2 A & 8.4 Tarea 2.4.3).
// Diffuse light is quantised into three bands (lit, mid tone, shadow); the albedo comes from the
// vertex colours of the single combined surface, which already carry the baked occlusion.
// The varnish specular clearcoat and rim light evoke high-end polished wood studio mannequins.
shader_type spatial;
render_mode cull_back;

uniform float band_threshold : hint_range(0.0, 1.0) = 0.35;
uniform float band_softness : hint_range(0.0, 0.2) = 0.03;
uniform float lit_tone : hint_range(0.0, 1.0) = 0.85;
uniform float mid_tone : hint_range(0.0, 1.0) = 0.5;
uniform float varnish_specular : hint_range(0.0, 1.0) = 0.45;
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.35;
	SPECULAR = 0.5;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(band_threshold - band_softness, band_threshold + band_softness, ndl);
	float facing = smoothstep(-band_softness, band_softness, ndl);
	// LIGHT_COLOR carries a factor of PI; dividing keeps the scale of the Lambert material it replaces.
	DIFFUSE_LIGHT += facing * mix(mid_tone, lit_tone, lit) * ATTENUATION * LIGHT_COLOR / PI;

	// Polished wood varnish clearcoat highlight (Blinn-Phong micro-facet)
	vec3 H = normalize(VIEW + LIGHT);
	float ndh = max(dot(NORMAL, H), 0.0);
	float spec = smoothstep(0.91, 0.96, ndh) * varnish_specular;
	SPECULAR_LIGHT += spec * LIGHT_COLOR * ATTENUATION / PI;

	// Subtle studio rim light for volumetric depth and figure-ground separation
	float vdn = 1.0 - max(dot(VIEW, NORMAL), 0.0);
	float rim = smoothstep(0.68, 0.98, vdn) * max(dot(-LIGHT, NORMAL) + 0.2, 0.0) * rim_intensity;
	DIFFUSE_LIGHT += rim * LIGHT_COLOR / PI;
}
