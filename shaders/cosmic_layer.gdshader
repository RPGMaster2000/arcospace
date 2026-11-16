shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D source_texture : source_color, hint_default_white;
uniform bool use_texture = false;
// Opt-in map accent: sample a localized angular window of an existing panorama.
// Defaults preserve every existing layer and encounter material.
uniform bool panorama_patch = false;
uniform float patch_extent = 0.48;
uniform float panorama_gain = 0.48;
uniform bool galaxy = false;
// Optional map-only profiles: nebula, galaxy, dust lane, remnant, quasar.
uniform int phenomenon = 0;
uniform bool billboard = false;
// Enabled only for map sky decorations; encounter nebulae stay in world space.
uniform bool camera_relative = false;
uniform vec3 sky_direction = vec3(0.0,0.0,-1.0);
uniform vec3 reference_origin;
uniform float sky_parallax = 0.0;
uniform vec4 tint : source_color = vec4(0.3,0.4,0.7,1.0);
uniform float opacity = 0.2;
uniform float foreground_protection = 0.0;
uniform float rotation = 0.0;
uniform float variation = 0.0;
float hash2(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 if (camera_relative && !panorama_patch) {
  vec3 center = CAMERA_POSITION_WORLD+sky_direction*55.0-(CAMERA_POSITION_WORLD-reference_origin)*sky_parallax;
  MODELVIEW_MATRIX = VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],vec4(center,1.0));
 } else if (billboard) MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
 if (panorama_patch) MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(1.0,0.0,0.0,0.0),vec4(0.0,1.0,0.0,0.0),vec4(0.0,0.0,1.0,0.0),vec4(CAMERA_POSITION_WORLD,1.0));
 POSITION = PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.0);
 if (camera_relative) {
  // A small opt-in far-plane inset avoids precision loss on transparent
  // angular caps. World geometry still occludes them with normal depth tests.
  POSITION.z = (CLIP_SPACE_FAR + (panorama_patch ? 0.00001 : 0.0))*POSITION.w;
 }
}
void fragment() {
 vec2 p = UV - 0.5;
 p = mat2(vec2(cos(rotation),-sin(rotation)),vec2(sin(rotation),cos(rotation))) * p;
 float edge = 1.0-smoothstep(0.25,0.5,length(p));
 float cloud = noise(p*5.0+variation)*0.6+noise(p*11.0+variation)*0.3+noise(p*23.0+variation)*0.1;
 float r = length(p*vec2(1.0,2.2));
 float arms = 0.55+0.45*sin(atan(p.y*2.2,p.x)*2.0-r*25.0);
 float alpha = galaxy ? (exp(-r*11.0)*0.7+exp(-r*7.0)*arms*0.5) : cloud*edge;
 if (phenomenon == 2) alpha = cloud * exp(-abs(p.y + sin(p.x*9.0+variation)*0.045)*16.0) * edge;
 if (phenomenon == 3) alpha = exp(-pow((length(p)-0.28)*27.0,2.0)) * (0.35+cloud*0.65) * edge;
 if (phenomenon == 4) {
  float core = exp(-length(p)*95.0);
  float disc = exp(-length(p*vec2(1.0,5.0))*18.0)*0.5;
  float jets = exp(-abs(p.x)*180.0)*exp(-abs(p.y)*7.0)*0.7;
  alpha = core+disc+jets;
 }
 vec4 image = texture(source_texture,p+0.5);
 ALBEDO = tint.rgb * (use_texture ? image.rgb : vec3(1.0));
 float corridor = 1.0-smoothstep(0.55,1.15,length((SCREEN_UV-vec2(0.5,0.48))/vec2(0.42,0.36)));
 ALPHA = opacity * (use_texture ? image.a : alpha) * edge * (1.0-corridor*foreground_protection);
 if (panorama_patch) {
  vec2 panorama_uv = UV;
  vec2 dx = dFdx(panorama_uv), dy = dFdy(panorama_uv);
  dx.x -= round(dx.x); dy.x -= round(dy.x);
  vec3 source = textureGrad(source_texture,vec2(fract(panorama_uv.x),clamp(panorama_uv.y,0.001,0.999)),dx,dy).rgb;
  float mask = 1.0-smoothstep(patch_extent*0.45,patch_extent,length(UV2));
  ALBEDO = source * panorama_gain;
  ALPHA = opacity * mask * (1.0-corridor*foreground_protection);
 }
}
