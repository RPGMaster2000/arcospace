shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform float opacity = 0.12;
void fragment() {
 vec2 p = UV*2.0-1.0;
 // Soft, asymmetric chips: broad enough to remain stable below native resolution.
 float edge = max(abs(p.x)*0.85+abs(p.y)*0.45, abs(p.y)+p.x*0.2);
 ALBEDO = mix(vec3(0.35,0.41,0.48), vec3(0.70,0.77,0.84), UV.y);
 ALPHA = opacity*(1.0-smoothstep(0.45,0.95,edge));
}
