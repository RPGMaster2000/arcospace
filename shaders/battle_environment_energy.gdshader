shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
// World geometry, normal depth testing. No screen textures or full-screen pass.
uniform vec4 energy_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.7;
uniform float motion_scale = 1.0;
uniform float phase = 0.0;
uniform bool electrical = false;
uniform float distortion = 0.0;
void vertex() {
 VERTEX += NORMAL * sin(VERTEX.y*0.3 + TIME*0.18*motion_scale + phase)*distortion;
}
void fragment() {
 float cycle = sin(TIME * 0.22 * motion_scale + phase);
 float activity = electrical ? smoothstep(0.80, 1.0, cycle) : (0.55 + 0.15 * cycle);
 ALBEDO = energy_color.rgb * (0.65 + activity * 0.35);
 ALPHA = opacity * (electrical ? 0.14 + activity * 0.65 : 0.65 + activity * 0.35);
}
