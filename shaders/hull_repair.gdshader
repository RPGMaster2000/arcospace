shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float lower_y = 61.0;
uniform float upper_y = -61.0;
varying float local_y;
void vertex() { local_y = VERTEX.y; }
void fragment() {
    float height = (lower_y - local_y) / max(lower_y - upper_y, 0.001);
    float band = exp(-pow((height - (progress * 1.5 - 0.25)) / 0.23, 2.0));
    float envelope = sin(progress * 3.14159265);
    vec3 tint = mix(vec3(0.15, 0.55, 1.0), vec3(0.9, 0.98, 1.0), band);
    COLOR = vec4(tint, (0.12 + band * 0.68) * envelope);
}
