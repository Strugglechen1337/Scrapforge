shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Industrial floor: MetalPlates001 is the base layer (visible plate grid), the
// low-resolution mask adds tone, rust and oil; Concrete034 only shows through
// as worn-out patches. Eight texture samples per pixel in total.
uniform sampler2D metal_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metal_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metal_rough : filter_linear_mipmap, repeat_enable;
uniform sampler2D concrete_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D floor_mask : filter_linear_mipmap, repeat_enable;
uniform float brightness = 0.056;
uniform float normal_depth = 0.3;

void fragment() {
	vec2 uv = UV * vec2(10.0, 6.875); // one texture tile = 8 m, plates about 2 m
	vec3 mask = texture(floor_mask, UV).rgb;               // macro: tone, wear, rust
	vec3 grunge = texture(floor_mask, UV * vec2(7.0, 5.0) + vec2(0.31, 0.57)).rgb; // meso detail, breaks the tile
	float tone = mix(0.85, 1.15, mask.g) * mix(0.9, 1.1, grunge.b);
	float wear = smoothstep(0.70, 0.80, mask.r * 0.65 + grunge.r * 0.35 + (grunge.b - 0.5) * 0.15);
	float rust = smoothstep(0.58, 0.85, mask.b * 0.6 + grunge.g * 0.4);
	float oil = smoothstep(0.7, 0.9, mask.g * 0.5 + grunge.r * 0.5);

	vec3 metal = texture(metal_color, uv).rgb * brightness * tone;
	vec3 concrete = texture(concrete_color, uv * 0.5 + vec2(0.13, 0.27)).rgb * 0.06;
	vec3 base = mix(metal, vec3(0.05, 0.03, 0.02) * (0.6 + grunge.g), rust * 0.12);
	base = mix(base, concrete, wear * 0.6);
	base = mix(base, base * 0.7, oil * 0.6);
	ALBEDO = max(base, vec3(0.020));

	float rough = texture(metal_rough, uv).r;
	METALLIC = mix(0.4, 0.1, max(rust * 0.7, wear));
	ROUGHNESS = clamp(mix(rough, 0.92, max(rust, wear) * 0.8) + (grunge.g - 0.5) * 0.25 - oil * 0.25, 0.55, 0.95);
	NORMAL_MAP = texture(metal_normal, uv).rgb;
	NORMAL_MAP_DEPTH = normal_depth * (1.0 - wear * 0.6);
}
