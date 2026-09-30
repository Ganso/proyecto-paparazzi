// Realistic shading of Ultra's hd mannequins (docs/futuro/17 fase 5): standard physically based
// lighting (shadows, GI and reflections like the rest of the scene) instead of toon bands, with the
// ink outline kept as a next pass (cel_outline.gdshader). Varnished wood gets a clearcoat; cloth is
// matte with a soft rim that reads as fibre fuzz. Vertex colours are sRGB values.
shader_type spatial;
render_mode cull_back;

uniform bool textured = true;
uniform float texture_strength : hint_range(0.0, 1.0) = 1.0;
uniform float clearcoat_amount : hint_range(0.0, 1.0) = 0.55;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.3;

#include "res://shaders/mannequin_patterns.gdshaderinc"

void fragment() {
	// Thin pieces seen edge-on (hat brims) can interpolate a zero normal: normalising it gave NaN
	// lighting, one pixel that the glow blew up into a white flash. Fall back to facing the camera.
	NORMAL = dot(NORMAL, NORMAL) > 1e-8 ? normalize(NORMAL) : VIEW;
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	if (textured) ALBEDO = textured_albedo(ALBEDO, texture_strength);
	if (zone < 0.5) {
		// Varnished wood.
		ROUGHNESS = 0.42;
		SPECULAR = 0.5;
		CLEARCOAT = clearcoat_amount;
		CLEARCOAT_ROUGHNESS = 0.3;
	} else if (zone < 2.5) {
		// Knit and twill.
		ROUGHNESS = 0.92;
		SPECULAR = 0.25;
		RIM = rim_amount;
		RIM_TINT = 0.6;
	} else if (zone < 3.5) {
		// Hair and hats.
		ROUGHNESS = 0.7;
		SPECULAR = 0.35;
	} else {
		// Shoes, trims and accessories.
		ROUGHNESS = 0.55;
		SPECULAR = 0.4;
	}
}
