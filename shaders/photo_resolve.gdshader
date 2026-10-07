shader_type canvas_item;
render_mode unshaded;
// The accumulated exposure (linear, floating point) back to an sRGB image, with a little noise of
// half a step so that 8 bits do not band the skies.

vec3 to_srgb(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

void fragment() {
	float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	COLOR = vec4(to_srgb(texture(TEXTURE, UV).rgb) + n / 255.0, 1.0);
}
