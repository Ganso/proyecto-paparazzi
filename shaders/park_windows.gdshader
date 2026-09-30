// Skyline windows (docs/futuro/17 fase 4): glass colour by day; at golden hour and night the
// windows whose vertex alpha is 1 light up with a warm glow (about one in three).
shader_type spatial;
render_mode cull_back;

uniform float lit : hint_range(0.0, 1.0) = 0.0;
uniform vec3 glow_color : source_color = vec3(1.0, 0.8, 0.5);
uniform float glow_energy = 2.5;

void fragment() {
	// Vertex colours are sRGB values (Ultra only uses this material).
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * (1.0 - 0.7 * lit * COLOR.a);
	ROUGHNESS = 0.15;
	SPECULAR = 0.7;
	EMISSION = glow_color * glow_energy * lit * COLOR.a;
}
