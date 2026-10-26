shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float opacity : hint_range(0.0, 1.0) = 0.8;
void fragment() {
 // Cylinder UV.y runs from the nozzle (top) to the distant tail (bottom).
 float tail = pow(1.0 - smoothstep(0.0, 1.0, UV.y), 1.5);
 float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.4);
 vec3 color = mix(vec3(0.65, 0.94, 1.0), vec3(0.12, 0.55, 1.0), UV.y);
 ALBEDO = color;
 EMISSION = color * 0.5;
 ALPHA = opacity * tail * edge;
}
