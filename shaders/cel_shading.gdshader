// Toon shading for the wooden mannequins (docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md, 3.2 A).
// Diffuse light is quantised into three bands (lit, mid tone, shadow); the albedo comes from the
// vertex colours of the single combined surface, which already carry the baked occlusion.
// The Compatibility renderer shades in the same space the vertex colours are authored in,
// so they are used as they are (an sRGB-to-linear conversion darkened every garment).
shader_type spatial;
render_mode cull_back;

uniform float band_threshold : hint_range(0.0, 1.0) = 0.35;
uniform float band_softness : hint_range(0.0, 0.2) = 0.03;
uniform float lit_tone : hint_range(0.0, 1.0) = 0.85;
uniform float mid_tone : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(band_threshold - band_softness, band_threshold + band_softness, ndl);
	float facing = smoothstep(-band_softness, band_softness, ndl);
	// LIGHT_COLOR carries a factor of PI; dividing keeps the scale of the Lambert material it replaces.
	DIFFUSE_LIGHT += facing * mix(mid_tone, lit_tone, lit) * ATTENUATION * LIGHT_COLOR / PI;
}
