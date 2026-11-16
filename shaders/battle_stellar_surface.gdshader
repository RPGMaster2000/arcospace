shader_type spatial;
render_mode unshaded, fog_disabled;
uniform float motion_scale = 1.0;
varying vec3 surface_point;
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7)))*43758.5453); }
float cells(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
 mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { surface_point = VERTEX; }
void fragment() {
 float t = TIME * 0.025 * motion_scale;
 float granules = cells(surface_point*0.8+vec3(0,t,0))*0.7+cells(surface_point*2.6-vec3(t,0,0))*0.3;
 float edge = pow(clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),0.35);
 vec3 warm = mix(vec3(0.60,0.08,0.015),vec3(1.0,0.62,0.16),smoothstep(0.12,0.90,granules));
 ALBEDO = warm * (0.30+edge*0.70);
}
