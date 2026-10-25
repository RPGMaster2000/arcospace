shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform float opacity = 0.12;
void fragment() {
 vec2 p = UV*2.0-1.0;
 ALBEDO = vec3(0.65,0.78,0.95);
 ALPHA = opacity*exp(-dot(p,p)*4.0)*(1.0-smoothstep(0.7,1.0,length(p)));
}
