shader_type sky;
// The park's sky (docs/ESCENARIO_Y_RENDIMIENTO.md §3): the same vertical gradient and sun as the
// engine's procedural sky, plus what it lacked: stars and a moon at night, high cirrus streaks and
// an afterglow over the horizon where the sun went down (golden and blue hours).
// Nothing here moves (no TIME): the sky radiance is rendered once per time of day, not every frame.
uniform vec3 sky_top_color : source_color = vec3(.44,.64,.81);
uniform vec3 sky_horizon_color : source_color = vec3(.86,.91,.92);
uniform vec3 ground_horizon_color : source_color = vec3(.77,.83,.79);
uniform vec3 ground_bottom_color : source_color = vec3(.45,.5,.39);
uniform float sky_curve = .15;
uniform float ground_curve = .02;
uniform float sun_angle_max = 30.0;
uniform float sun_curve = .15;
// 1 at night: the directional light is the moon and is drawn as one.
uniform float moon = 0.0;
// The moon hangs lower than the light it casts (same azimuth), where the photographer can see it.
uniform vec3 moon_direction = vec3(0.0,.6,.8);
uniform float stars = 0.0;
uniform float cirrus = .5;
uniform vec3 cirrus_color : source_color = vec3(1.0);
uniform vec3 glow_color : source_color = vec3(1.0,.6,.35);
uniform float glow = 0.0;
uniform vec3 glow_direction = vec3(0.0,0.0,1.0);

float hash3(vec3 p) {
	p = fract(p*vec3(.1031,.1030,.0973));
	p += dot(p,p.yxz+33.33);
	return fract((p.x+p.y)*p.z);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	float a = hash3(vec3(i,1.7));
	float b = hash3(vec3(i+vec2(1.0,0.0),1.7));
	float c = hash3(vec3(i+vec2(0.0,1.0),1.7));
	float d = hash3(vec3(i+vec2(1.0,1.0),1.7));
	return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = .5;
	for (int i = 0; i < 5; i++) {
		v += a*noise2(p);
		p = p*2.03+vec2(17.0,9.0);
		a *= .5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float v_angle = acos(clamp(dir.y,-1.0,1.0));
	vec3 color;
	if (dir.y >= 0.0) {
		float c = 1.0-v_angle/(PI*.5);
		color = mix(sky_horizon_color,sky_top_color,clamp(1.0-pow(1.0-c,1.0/sky_curve),0.0,1.0));
		// Afterglow: a warm band low over the horizon, on the side where the sun set.
		vec2 flat_dir = normalize(dir.xz+vec2(.00001));
		float side = .5+.5*dot(flat_dir,normalize(glow_direction.xz));
		color = mix(color,glow_color,glow*pow(side,2.0)*exp(-dir.y*7.0));
		// High cirrus: stretched noise on a plane far above, thinning out towards the horizon.
		if (cirrus > 0.0) {
			vec2 uv = dir.xz/(dir.y+.18);
			float streaks = fbm(vec2(uv.x*1.1+uv.y*.35,uv.y*3.2));
			float veil = smoothstep(.5,.82,streaks)*smoothstep(.03,.3,dir.y)*cirrus;
			float lit = LIGHT0_ENABLED ? pow(max(dot(dir,LIGHT0_DIRECTION),0.0),6.0) : 0.0;
			color = mix(color,cirrus_color*(1.0+.5*lit),veil*.75);
		}
		if (stars > 0.0 && !AT_CUBEMAP_PASS) {
			vec3 p = dir*90.0;
			vec3 cell = floor(p);
			float h = hash3(cell);
			if (h > .988) {
				vec3 offset = vec3(hash3(cell+11.0),hash3(cell+23.0),hash3(cell+37.0))*.6+.2;
				float d = length(fract(p)-offset);
				float size = mix(.12,.3,hash3(cell+51.0));
				vec3 tint = mix(vec3(1.0,.86,.7),vec3(.75,.85,1.0),hash3(cell+71.0));
				color += tint*stars*smoothstep(size,0.0,d)*smoothstep(.02,.25,dir.y)*(.5+1.2*hash3(cell+91.0));
			}
		}
		if (moon > .5) {
			// The moon: a pale disc with soft maria and a faint halo.
			vec3 to_moon = normalize(moon_direction);
			float moon_angle = acos(clamp(dot(to_moon,dir),-1.0,1.0));
			float size = radians(2.2);
			color += vec3(.62,.7,.9)*exp(-moon_angle*9.0)*.22;
			if (moon_angle < size) {
				vec2 face = (dir-to_moon).xz/size;
				float maria = smoothstep(.45,.7,fbm(face*2.2+5.0));
				color = mix(color,vec3(.95,.96,.9)*(1.0-.45*maria)*.95,smoothstep(size,size*.9,moon_angle));
			}
		} else if (LIGHT0_ENABLED) {
			float sun_angle = acos(clamp(dot(LIGHT0_DIRECTION,dir),-1.0,1.0));
			float size = radians(1.0);
			if (sun_angle < size) {
				color = LIGHT0_COLOR*LIGHT0_ENERGY;
			} else if (sun_angle < radians(sun_angle_max)) {
				float c2 = (sun_angle-size)/(radians(sun_angle_max)-size);
				color = mix(LIGHT0_COLOR*LIGHT0_ENERGY,color,clamp(1.0-pow(1.0-c2,1.0/sun_curve),0.0,1.0));
			}
		}
	} else {
		float c = (v_angle-PI*.5)/(PI*.5);
		color = mix(ground_horizon_color,ground_bottom_color,clamp(1.0-pow(1.0-c,1.0/ground_curve),0.0,1.0));
	}
	COLOR = color;
}
