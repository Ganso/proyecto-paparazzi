shader_type canvas_item;
uniform float coc_pixels = 0.0;
uniform float exposure = 0.0;
uniform vec2 motion = vec2(0.0);
uniform vec2 shake = vec2(0.0);
uniform float grain = 0.0;
uniform float shot_seed = 0.0;
float random(vec2 p) { return fract(sin(dot(p,vec2(12.9898,78.233))+shot_seed)*43758.5453); }
void fragment() {
 vec2 px = TEXTURE_PIXEL_SIZE;
 vec3 color = vec3(0.0);
 for(int i=0;i<17;i++) {
  float t=float(i)/16.0-.5;
  float a=float(i)*2.399963;
  vec2 blur=vec2(cos(a),sin(a))*sqrt(float(i)/16.0)*coc_pixels;
  color+=texture(TEXTURE,clamp(UV+px*(blur+t*motion+sin(float(i)*1.7)*shake),vec2(0.0),vec2(1.0))).rgb;
 }
 color/=17.0;
 color=pow(max(color,vec3(0.0)),vec3(1.0+clamp(exposure,-3.0,3.0)*.06))*exp2(-exposure);
 color+=(random(UV)-.5)*grain;
 COLOR=vec4(clamp(color,vec3(0.0),vec3(1.0)),1.0);
}
