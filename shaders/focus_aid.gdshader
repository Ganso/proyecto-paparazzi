shader_type canvas_item;
// The focusing aid of the cameras without autofocus: the rangefinder's double image (body 1) and
// the split image of the ground glass (the others). What is in focus lines up; what is not is
// doubled or split by its own distance, column by column (main.gd::update_focus_aid() measures
// eleven across the zone): a lamp post crossing in front splits only itself, instead of making
// the whole zone jump and come back as it did with a single offset.
uniform float offset = 0.0;           // (the zone's own: what the label and the tests go by)
uniform float offsets[11];
uniform int body = 2;
uniform bool mirror = false;   // TLR: the ground glass is seen mirrored

float local_offset(float px, float half_width) {
	float at = clamp(px / half_width * 0.5 + 0.5, 0.0, 1.0) * 10.0;
	return offsets[int(floor(at + 0.5))];
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.777778, 1.0);
	bool inside = body == 1 ? abs(p.x) < 0.095 && abs(p.y) < 0.048 : length(p) < 0.078;
	vec2 uv = UV;
	if (mirror) uv.x = 1.0 - uv.x;
	vec4 c = texture(TEXTURE, uv);
	if (inside) {
		float shift = local_offset(p.x, body == 1 ? 0.095 : 0.078);
		if (body == 1) {
			c = mix(c, texture(TEXTURE, uv + vec2(shift,0.0)), 0.5);
			c.rgb *= vec3(1.08,1.03,0.82);
		} else {
			uv.x += p.y > 0.0 ? shift : -shift;
			c = texture(TEXTURE, uv);
			if (abs(p.y) < 0.001) c.rgb *= 0.3;
		}
	}
	COLOR = vec4(c.rgb, inside ? 1.0 : 0.0);
}
