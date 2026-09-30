// Toon shading for the wooden mannequins (docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md, 3.2 A & 8.4 Tarea 2.4.3).
// Diffuse light is quantised into three bands (lit, mid tone, shadow); the albedo comes from the
// vertex colours of the single combined surface, which already carry the baked occlusion.
// The varnish specular clearcoat and rim light evoke high-end polished wood studio mannequins.
// Screen-space derivative anti-aliasing (fwidth) ensures smooth band transitions and eliminates
// pixelated staircasing and single-pixel specular chatter across all distances and angles.
shader_type spatial;
render_mode cull_back;

uniform float band_threshold : hint_range(0.0, 1.0) = 0.35;
uniform float band_softness : hint_range(0.0, 0.2) = 0.06;
uniform float lit_tone : hint_range(0.0, 1.0) = 0.85;
uniform float mid_tone : hint_range(0.0, 1.0) = 0.5;
uniform float varnish_specular : hint_range(0.0, 1.0) = 0.40;
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.20;
// Vertex colours are sRGB values. The mobile profiles use them as linear (their lighting is tuned
// to that paler look); Ultra linearises them for correct saturation (docs/futuro/17).
uniform bool linear_colors = false;
// Ultra's hd mannequins (docs/futuro/17 fase 5): procedural wood grain, knit, denim twill and hair
// strands. UV/UV2 carry the position in the bone's own space and UV2.y = zone * 100 + bone.
uniform bool textured = false;
uniform float texture_strength : hint_range(0.0, 1.0) = 1.0;

#include "res://shaders/mannequin_patterns.gdshaderinc"

void fragment() {
	// Thin pieces seen edge-on (hat brims) can interpolate a zero normal: normalising it gave NaN
	// lighting, one pixel that the glow blew up into a white flash. Fall back to facing the camera.
	NORMAL = dot(NORMAL, NORMAL) > 1e-8 ? normalize(NORMAL) : VIEW;
	ALBEDO = linear_colors ? pow(COLOR.rgb, vec3(2.2)) : COLOR.rgb;
	ROUGHNESS = 0.35;
	SPECULAR = 0.5;
	if (textured) {
		// Colour only: tilting the normal made single pixels jump between toon bands.
		ALBEDO = textured_albedo(ALBEDO, texture_strength);
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);

	// Screen-space derivative anti-aliasing:
	// Guarantees the band transition spans at least 1.5 screen pixels, eliminating
	// pixelated staircase artifacts and shimmering while preserving the crisp cel aesthetic.
	float ndl_deriv = fwidth(ndl);
	float w = max(band_softness, ndl_deriv * 1.5);
	float lit = smoothstep(band_threshold - w, band_threshold + w, ndl);

	float facing_w = max(band_softness, ndl_deriv * 1.5);
	float facing = smoothstep(-facing_w, facing_w, ndl);

	// LIGHT_COLOR carries a factor of PI; dividing keeps the scale of the Lambert material it replaces.
	DIFFUSE_LIGHT += facing * mix(mid_tone, lit_tone, lit) * ATTENUATION * LIGHT_COLOR / PI;

	// Polished wood varnish clearcoat highlight:
	// Smooth continuous micro-facet curve (pow) avoids single-pixel hot-pixel spikes
	// and creates an authentic lustrous satin lacquer finish across curved joints.
	vec3 H = normalize(VIEW + LIGHT);
	float ndh = max(dot(NORMAL, H), 0.0);
	float spec_soft = pow(ndh, 16.0) * 0.35;
	float spec_core = pow(ndh, 48.0) * 0.65;
	float spec = (spec_soft + spec_core) * varnish_specular;
	SPECULAR_LIGHT += spec * LIGHT_COLOR * ATTENUATION / PI;

	// Subtle studio rim light for volumetric depth and figure-ground separation
	float vdn = 1.0 - max(dot(VIEW, NORMAL), 0.0);
	float vdn_deriv = fwidth(vdn);
	float rim_w = max(0.08, vdn_deriv * 1.5);
	float rim = smoothstep(0.58 - rim_w, 0.95 + rim_w, vdn) * max(dot(-LIGHT, NORMAL) + 0.2, 0.0) * rim_intensity;
	DIFFUSE_LIGHT += rim * LIGHT_COLOR / PI;
}
