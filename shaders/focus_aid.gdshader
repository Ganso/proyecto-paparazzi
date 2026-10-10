shader_type canvas_item;
// The zone of the manual-focus aid over the finder: its tint (rangefinder) and the line across
// the split image. Where the 3D pass can do it (Forward+: viewfinder_dof.gdshader, which knows the
// distance of every pixel) the doubling or splitting is already in the image and `offset` is 0;
// otherwise (OpenGL) the whole zone is shifted here by one offset.
uniform float offset = 0.0;
uniform int body = 2;
uniform bool mirror = false;   // TLR: the ground glass is seen mirrored
void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.777778, 1.0);
	bool inside = body == 1 ? abs(p.x) < 0.095 && abs(p.y) < 0.048 : length(p) < 0.078;
	vec2 uv = UV;
	if (mirror) uv.x = 1.0 - uv.x;
	vec4 c = texture(TEXTURE, uv);
	if (inside) {
		if (body == 1) {
			c = mix(c, texture(TEXTURE, uv + vec2(offset,0.0)), 0.5);
			c.rgb *= vec3(1.08,1.03,0.82);
		} else {
			uv.x += p.y > 0.0 ? offset : -offset;
			c = texture(TEXTURE, uv);
			if (abs(p.y) < 0.001) c.rgb *= 0.3;
		}
	}
	COLOR = vec4(c.rgb, inside ? 1.0 : 0.0);
}
