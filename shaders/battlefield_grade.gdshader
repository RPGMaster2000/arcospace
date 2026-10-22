shader_type canvas_item;
render_mode unshaded;
// Lightweight raster adaptation of Rytelier ColorGrading SMH luminance ranges
// and preferential low-saturation vibrance. Display-referred, not compute/HDR.
// Reads the existing SubViewport texture once; no screen copy or blur textures.
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 shadow_tint = vec3(1.0);
uniform vec3 midtone_tint = vec3(1.0);
uniform vec3 highlight_tint = vec3(1.0);
uniform vec3 brightness = vec3(1.0);
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform float shadow_saturation = 1.0;
uniform float vibrance = 0.0;
uniform vec2 shadow_range = vec2(0.0, 0.35);
uniform vec2 highlight_range = vec2(0.55, 1.0);
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 c = source.rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	float shadow = 1.0 - smoothstep(shadow_range.x, shadow_range.y, luma);
	float highlight = smoothstep(highlight_range.x, highlight_range.y, luma);
	vec3 weights = vec3(shadow, max(0.0, 1.0-shadow-highlight), highlight);
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	float chroma = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	c = mix(vec3(luma), c, saturation * mix(1.0, shadow_saturation, weights.x) * (1.0 + vibrance * (1.0-clamp(chroma,0.0,1.0))));
	c *= weights.x * shadow_tint * brightness.x
		+ weights.y * midtone_tint * brightness.y
		+ weights.z * highlight_tint * brightness.z;
	c = clamp(c, vec3(0.0), vec3(1.0));
	c += (contrast-1.0) * (c-vec3(0.5)) * (4.0*c*(vec3(1.0)-c));
	COLOR = vec4(mix(source.rgb, clamp(c,vec3(0.0),vec3(1.0)),strength), source.a);
}
