shader_type canvas_item;
render_mode unshaded;

uniform vec4 shade : source_color;
uniform float direction : hint_range(-1.0, 1.0) = 0.0;
uniform float horizontal_fade : hint_range(0.1, 1.0) = 0.92;
uniform float vertical_fade : hint_range(0.1, 1.0) = 0.42;

void fragment() {
	float distance_from_title = direction < 0.0 ? UV.x
		: (direction > 0.0 ? 1.0 - UV.x : abs(UV.x * 2.0 - 1.0));
	float horizontal = 1.0 - smoothstep(1.0 - horizontal_fade, 1.0, distance_from_title);
	// Round off the anchored edges so they do not read as a panel outline.
	horizontal *= smoothstep(0.0, 0.045, UV.x) * smoothstep(0.0, 0.045, 1.0 - UV.x);
	float vertical = smoothstep(0.0, 0.11, UV.y) * (1.0 - smoothstep(1.0 - vertical_fade, 1.0, UV.y));
	COLOR *= vec4(shade.rgb, shade.a * horizontal * vertical);
}
