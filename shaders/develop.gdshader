shader_type canvas_item;

uniform float coc_pixels = 0.0;
uniform float exposure = 0.0;
uniform vec2 motion = vec2(0.0);
uniform vec2 shake = vec2(0.0);
// Panning (docs/futuro/11 §1.3): the sweep of the camera streaks everything by `pan` pixels except
// the subject, inside `subject_box` (centre and half size in UV), which keeps its own `motion`.
uniform vec2 pan = vec2(0.0);
uniform vec4 subject_box = vec4(0.5, 0.5, 0.0, 0.0);
uniform float grain = 0.0;      // stops of ISO over 100, times 0.035
uniform float film = 0.0;       // 1 on a roll of film: grain in clumps, no colour noise
uniform float shot_seed = 0.0;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.38;
uniform float chromatic_aberration : hint_range(0.0, 1.0) = 0.28;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 linear_to_srgb(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

float random(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + shot_seed) * 43758.5453);
}

// The glass (docs/SIMULACION_FOTOGRAFICA.md §9.5).
// distortion: + barrel (wide angles), − pincushion (telephotos).
uniform float distortion = 0.0;
// The sun in or near the frame: where (UV; may be outside) and how hard it veils the picture.
uniform vec2 sun_uv = vec2(-9.0);
uniform float sun_veil = 0.0;
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.62);
// Film halation: the red glow round what burns (0 on a sensor).
uniform float halation = 0.0;
// Point lights in the frame (the lamps at night) and how long their stars are (0 until f/11).
uniform vec2 lights[12];
uniform int light_count = 0;
uniform float star = 0.0;
uniform float aspect = 1.7778;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 uv_norm = UV - vec2(0.5);
	float r2 = dot(uv_norm * vec2(1.0, 0.5625), uv_norm * vec2(1.0, 0.5625));
	vec2 ca_dir = uv_norm * r2 * 0.03 * chromatic_aberration;
	// Distortion: straight lines bow out or in from the centre (kept inside the frame at the corners).
	vec2 lens_uv = vec2(0.5) + uv_norm * (1.0 + distortion * r2) / (1.0 + max(distortion, 0.0) * 0.329);

	vec2 streak = motion;
	if (dot(pan, pan) > 0.0 && subject_box.z > 0.0) {
		vec2 q = abs(UV - subject_box.xy) / subject_box.zw;
		float inside_subject = 1.0 - smoothstep(0.7, 1.2, max(q.x, q.y));
		streak = mix(pan, motion, inside_subject);
	}
	vec3 color = vec3(0.0);
	for (int i = 0; i < 17; i++) {
		float t = float(i) / 16.0 - 0.5;
		float a = float(i) * 2.399963;
		vec2 blur = vec2(cos(a), sin(a)) * sqrt(float(i) / 16.0) * coc_pixels;
		vec2 base_uv = lens_uv + px * (blur + t * streak + sin(float(i) * 1.7) * shake);

		float r = texture(TEXTURE, clamp(base_uv + ca_dir, vec2(0.0), vec2(1.0))).r;
		float g = texture(TEXTURE, clamp(base_uv, vec2(0.0), vec2(1.0))).g;
		float b = texture(TEXTURE, clamp(base_uv - ca_dir, vec2(0.0), vec2(1.0))).b;
		color += vec3(r, g, b);
	}
	color /= 17.0;

	// Exposure, in linear light (the capture is sRGB-encoded). Multiplying the encoded values and
	// clipping each channel on its own turned overexposed photos yellow, magenta and blue: like film
	// or a sensor, the highlights now roll off and lose saturation towards white instead.
	vec3 lin = srgb_to_linear(max(color, vec3(0.0))) * exp2(-exposure);
	float peak = max(max(lin.r, lin.g), lin.b);
	if (peak > 1.0) {
		// Keep the hue at full brightness and fade it to white as it burns (identity up to 1.0,
		// so a correctly exposed photo is untouched).
		lin /= peak;
		lin = mix(lin, vec3(1.0), clamp((peak - 1.0) / 2.5, 0.0, 1.0));
	}
	// Halation: light that crosses the film, bounces off its back and comes up again round the
	// highlights, in the red layer most of all.
	if (halation > 0.0) {
		float glow = 0.0;
		for (int i = 0; i < 16; i++) {
			float a = float(i) * 2.399963;
			vec2 off = vec2(cos(a), sin(a)) * (4.0 + 10.0 * sqrt(float(i) / 15.0)) * px * (1.0 / (px.x * 1280.0));
			vec3 near = srgb_to_linear(texture(TEXTURE, clamp(lens_uv + off, vec2(0.0), vec2(1.0))).rgb) * exp2(-exposure);
			glow += max(max(near.r, max(near.g, near.b)) - 0.75, 0.0);
		}
		lin += vec3(1.0, 0.32, 0.12) * glow / 16.0 * halation;
	}
	// The sun in front of the lens: a veil of its own light over everything (less contrast, lifted
	// shadows), stronger towards it, and its glow where it is.
	if (sun_veil > 0.0) {
		vec2 to_sun = (UV - sun_uv) * vec2(aspect, 1.0);
		float away = length(to_sun);
		float veil = sun_veil * (0.35 + 0.65 * exp(-away * 1.6));
		float glow = sun_veil * exp(-away * away * 18.0) * 1.4;
		lin += sun_color * (veil * 0.16 + glow);
	}
	// Stars on the point lights, once the aperture is small: six points from its blades' edges.
	if (star > 0.0) {
		for (int i = 0; i < light_count; i++) {
			vec2 d = (UV - lights[i]) * vec2(aspect, 1.0);
			float far = length(d);
			if (far > 0.25) continue;
			float points = 0.0;
			for (int k = 0; k < 3; k++) {
				float a = 0.26 + float(k) * 1.0472;
				vec2 along = vec2(cos(a), sin(a));
				float off_line = abs(d.x * along.y - d.y * along.x);
				points += exp(-off_line * off_line * 90000.0);
			}
			lin += vec3(1.0, 0.9, 0.7) * points * exp(-far / (0.035 * star)) * 0.9 * star;
		}
	}
	// Noise, in linear light (docs/SIMULACION_FOTOGRAFICA.md §9.4). A sensor: photon noise that
	// grows with the root of the light plus a floor that shows in the shadows, partly of colour.
	// Film: clumps of grain two pixels across, without colour, there even at ISO 100.
	vec2 cell = FRAGCOORD.xy;
	vec3 fine = vec3(random(cell * 0.731), random(cell * 0.517 + 11.0), random(cell * 0.893 + 23.0)) - 0.5;
	float mono = random(cell * 0.611 + 37.0) - 0.5;
	float clump = (random(floor(cell / 2.0) + 53.0) + random(floor((cell + 1.0) / 3.0) + 71.0)) * 0.5 - 0.5;
	vec3 sigma = 0.55 * sqrt(max(lin, vec3(0.0))) + 0.05;
	vec3 sensor = mix(vec3(mono), fine, 0.5) * sigma * grain * 1.5;
	vec3 emulsion = vec3(mix(mono, clump, 0.65)) * sigma * (grain + 0.03) * 2.1;
	lin = max(lin + mix(sensor, emulsion, film), vec3(0.0));
	color = linear_to_srgb(lin);

	// Optical lens vignetting (natural cos^4 falloff simulation)
	float vig = clamp(1.0 - r2 * 2.4 * vignette_amount, 0.0, 1.0);
	vig = smoothstep(0.0, 1.0, vig);
	color *= mix(0.70, 1.0, vig);

	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
