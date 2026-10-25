shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D source_texture : source_color, hint_default_white;
uniform bool use_texture = false;
uniform bool galaxy = false;
uniform bool billboard = false;
uniform vec4 tint : source_color = vec4(0.3,0.4,0.7,1.0);
uniform float opacity = 0.2;
uniform float rotation = 0.0;
uniform float variation = 0.0;
float hash2(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 if (billboard) MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment() {
 vec2 p = UV - 0.5;
 p = mat2(vec2(cos(rotation),-sin(rotation)),vec2(sin(rotation),cos(rotation))) * p;
 float edge = 1.0-smoothstep(0.25,0.5,length(p));
 float cloud = noise(p*5.0+variation)*0.6+noise(p*11.0+variation)*0.3+noise(p*23.0+variation)*0.1;
 float r = length(p*vec2(1.0,2.2));
 float arms = 0.55+0.45*sin(atan(p.y*2.2,p.x)*2.0-r*25.0);
 float alpha = galaxy ? (exp(-r*11.0)*0.7+exp(-r*7.0)*arms*0.5) : cloud*edge;
 vec4 image = texture(source_texture,p+0.5);
 ALBEDO = tint.rgb * (use_texture ? image.rgb : vec3(1.0));
 ALPHA = opacity * (use_texture ? image.a : alpha) * edge;
}
