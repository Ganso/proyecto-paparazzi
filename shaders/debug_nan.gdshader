// Debug pass (main.gd --debug-off=…,nanview): paints non-finite HDR pixels magenta and absurdly
// bright ones (> 1000) cyan, reading the opaque pass before tone mapping and glow.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	bool bad = any(isnan(c)) || any(isinf(c));
	bool hot = max(c.r, max(c.g, c.b)) > 1000.0;
	ALBEDO = bad ? vec3(1.0, 0.0, 1.0) : (hot ? vec3(0.0, 1.0, 1.0) : c * 0.15);
}
