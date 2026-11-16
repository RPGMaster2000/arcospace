shader_type spatial;
render_mode fog_disabled;
uniform vec4 metal_color : source_color = vec4(0.27,0.34,0.40,1.0);
uniform float motion_scale = 1.0;
void vertex() {
 // Bounded, local fragment rotation; no movement into combat or departure lanes.
 float a = sin(TIME*0.07*motion_scale+INSTANCE_CUSTOM.r*6.28)*0.20;
 mat3 turn=mat3(vec3(cos(a),0,-sin(a)),vec3(0,1,0),vec3(sin(a),0,cos(a)));
 VERTEX=turn*VERTEX;
 NORMAL=turn*NORMAL;
}
void fragment() {
 ALBEDO=metal_color.rgb;
 METALLIC=0.78;
 ROUGHNESS=0.42;
}
