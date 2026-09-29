// Ink outline for the mannequins: inverted hull drawn as the material's next_pass
// (docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md, 3.2 B). Only back faces are drawn, pushed out
// along the normal. The push is a constant width in pixels, capped in metres, so the line
// neither vanishes on the far lane nor grows thick on close-ups.
// Vertex-colour harmonic tinting blends the ink line with the underlying material (warm umber
// on polished wood, rich deep tones on garments) for authentic hand-inked illustration aesthetic.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.10, 0.10, 0.12, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.45;
uniform float width_px : hint_range(0.5, 4.0) = 1.6;
uniform float max_width_m : hint_range(0.005, 0.03) = 0.012;
uniform float depth_bias : hint_range(0.0, 0.01) = 0.0015;
// Lines thinner than a pixel break into dashes: never draw them below this width.
uniform float min_width_px : hint_range(0.0, 2.0) = 1.0;

void vertex() {
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist_to_cam = -view_pos.z;
	bool orthogonal = PROJECTION_MATRIX[3][3] > 0.5;
	float metres_per_px = 2.0 * (orthogonal ? 1.0 : -view_pos.z) / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);

	// Smooth cubic falloff between 6.5m and 17.5m prevents visual popping across lanes
	// and keeps far pedestrians from cluttering the frame with heavy outlines.
	float dist_factor = clamp((dist_to_cam - 6.5) / 11.0, 0.0, 1.0);
	float dist_atten = mix(1.0, 0.35, smoothstep(0.0, 1.0, dist_factor));

	float offset = max(min(width_px * metres_per_px, max_width_m) * dist_atten, min_width_px * metres_per_px);
	VERTEX += NORMAL * offset;

	// View-space depth bias: pushes inverted back-faces slightly away from the camera along the view ray.
	// This prevents back-face outline geometry from clipping or poking through forward-facing curved joints
	// (such as spherical knees, elbows, and chin) at steep viewing angles.
	vec3 view_dir = normalize(view_pos);
	vec3 model_view_dir = (inverse(MODELVIEW_MATRIX) * vec4(view_dir, 0.0)).xyz;
	VERTEX += model_view_dir * (depth_bias * dist_atten);

	// Vertices flagged with alpha 0 (double-sided cloth panels) collapse, so no hull is drawn for them.
	VERTEX *= step(0.5, COLOR.a);
}

void fragment() {
	// Harmonise ink line with surface vertex colour:
	// Blending the dark ink baseline with a deep shaded version of the surface vertex colour
	// gives warm umber/walnut contours to wood joints, deep navy to denim, and rich tones to garments.
	vec3 shaded_base = COLOR.rgb * 0.20;
	ALBEDO = mix(outline_color.rgb, shaded_base, tint_strength);
}
