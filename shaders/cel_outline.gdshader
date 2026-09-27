// Ink outline for the mannequins: inverted hull drawn as the material's next_pass
// (docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md, 3.2 B). Only back faces are drawn, pushed out
// along the normal. The push is a constant width in pixels, capped in metres, so the line
// neither vanishes on the far lane nor grows thick on close-ups.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.12, 0.12, 0.14, 1.0);
uniform float width_px = 1.6;
uniform float max_width_m = 0.012;

void vertex() {
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist_to_cam = -view_pos.z;
	bool orthogonal = PROJECTION_MATRIX[3][3] > 0.5;
	float metres_per_px = 2.0 * (orthogonal ? 1.0 : -view_pos.z) / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
	// Softly taper outline thickness in distance so far pedestrians do not clutter the frame
	float dist_atten = clamp(1.0 - (dist_to_cam - 7.0) / 10.0, 0.35, 1.0);
	VERTEX += NORMAL * min(width_px * metres_per_px, max_width_m) * dist_atten;
	// Vertices flagged with alpha 0 (double-sided cloth panels) collapse, so no hull is drawn for them.
	VERTEX *= step(0.5, COLOR.a);
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
