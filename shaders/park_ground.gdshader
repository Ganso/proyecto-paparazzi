// Textured park ground for Ultra (docs/futuro/17 fase 2). The rings of the park share this
// material: the vertex alpha selects the layer of the texture arrays (alpha = layer / 10) and the
// vertex RGB carries the baked contact occlusion. Textures come from tools/texturas/build_textures.py
// and are mapped in world space, so the circular paths need no UVs.
// Normal maps use the generator's own convention: R = world x, G = world z, B = up.
shader_type spatial;
render_mode cull_back;

uniform sampler2DArray albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray orm_tex : filter_linear_mipmap_anisotropic, repeat_enable;
// Size in metres of one texture repeat, per layer.
uniform float tile_size[8];
uniform float normal_strength = 1.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float layer = floor(COLOR.a * 10.0 + 0.5);
	vec2 uv = world_position.xz / tile_size[int(layer)];
	vec3 albedo = texture(albedo_tex, vec3(uv, layer)).rgb;
	// A second, larger and rotated sample of the same layer breaks the visible repetition.
	vec2 macro_uv = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.27;
	vec3 macro = texture(albedo_tex, vec3(macro_uv, layer)).rgb;
	float macro_luma = dot(macro, vec3(0.333));
	albedo *= mix(0.86, 1.14, macro_luma / max(dot(albedo, vec3(0.333)), 0.05) * 0.5);
	vec3 orm = texture(orm_tex, vec3(uv, layer)).rgb;
	vec3 n = texture(normal_tex, vec3(uv, layer)).rgb * 2.0 - 1.0;
	vec3 world_normal = normalize(vec3(n.r * normal_strength, n.b, n.g * normal_strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	ALBEDO = albedo * COLOR.rgb;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.4;
	ROUGHNESS = orm.g;
	SPECULAR = 0.35;
}
