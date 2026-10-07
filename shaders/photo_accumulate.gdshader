shader_type canvas_item;
render_mode blend_mix, unshaded;
// The virtual shutter (scripts/main.gd::expose_photo()): each frame rendered during the exposure
// is blended over the accumulator with weight 1/(k+1), a running mean in linear light.
// decode: the frame arrives sRGB-encoded (OpenGL); in Forward+ the HDR 2D canvas already hands
// it over in linear light.
uniform float weight = 1.0;
uniform bool decode = true;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	COLOR = vec4(decode ? to_linear(c) : c, weight);
}
