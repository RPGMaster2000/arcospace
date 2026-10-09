shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    float radius = length(UV * 2.0 - 1.0);
    float wave = exp(-pow((radius - progress) / 0.14, 2.0));
    float edge = 1.0 - smoothstep(0.94, 1.0, radius);
    COLOR = vec4(0.3, 0.8, 1.0, wave * edge * sin(progress * 3.14159265) * 0.55);
}
