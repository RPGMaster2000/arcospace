#[vertex]
#version 450
void main() {
    vec2 p = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
#[fragment]
#version 450
layout(set = 0, binding = 0) uniform sampler2D lens_texture;
layout(location = 0) out vec4 color;
void main() {
    color = vec4(texelFetch(lens_texture, ivec2(gl_FragCoord.xy), 0).rgb, 0.0);
}
