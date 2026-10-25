shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, skip_vertex_transform;
uniform float opacity = 0.55;
uniform vec3 reference_origin;
uniform mat3 reference_basis;
uniform float parallax = 0.8;
uniform float near_depth = 5.0;
varying float depth_fade;
void vertex() {
 // Evaluate against the SAME camera matrix as the rendered scene, not last frame's
 // CPU sky transform. Deterministic wrapping keeps points nearby during long pans.
 vec3 displacement = transpose(reference_basis)*(CAMERA_POSITION_WORLD-reference_origin)*parallax;
 vec3 seed_position = MODEL_MATRIX[3].xyz;
 vec2 plane = mod(seed_position.xy-displacement.xy+vec2(12.0,6.0),vec2(24.0,12.0))-vec2(12.0,6.0);
 float depth = mod(-seed_position.z+displacement.z-near_depth,4.0);
 depth_fade = smoothstep(0.0,0.5,depth)*(1.0-smoothstep(3.5,4.0,depth));
 vec3 center = CAMERA_POSITION_WORLD+reference_basis*vec3(plane,-near_depth-depth);
 VERTEX = (VIEW_MATRIX*vec4(center,1.0)).xyz+vec3(VERTEX.xy,0.0);
}
void fragment() {
 vec2 p = UV*2.0-1.0;
 float radius = length(p);
 float aa = max(fwidth(radius),0.08);
 ALBEDO = vec3(1.0);
 ALPHA = opacity*depth_fade*(1.0-smoothstep(0.45-aa,0.65+aa,radius));
}
