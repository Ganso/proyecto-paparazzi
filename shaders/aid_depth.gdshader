shader_type spatial;
// How far away each point of the focusing zone is (main.gd::update_aid_optics()): a small view of
// the middle of the frame, from the camera's own place, that writes the distance of every pixel
// (metres / 100) instead of its colour. The split image and the double image are drawn from it
// (shaders/focus_aid.gdshader): rays against the colliders, which are capsules, cannot say where
// the outline of a person is.
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 view = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV, depth) * 2.0 - 1.0, 1.0);
#else
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
#endif
	float z = abs(view.w) < 1e-6 ? 1000.0 : clamp(-view.z / view.w, 0.0, 1000.0);
	ALBEDO = vec3(z / 100.0);
}
