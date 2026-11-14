shader_type spatial;

uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform sampler2D paint_mask : filter_linear_mipmap;

uniform vec4 paint_color : source_color = vec4(0.66, 0.64, 0.60, 1.0);
uniform vec4 accent_color : source_color = vec4(0.91, 0.45, 0.13, 1.0);
uniform int pattern_mode = 0; // 0: stripes, 1: hazard, 2: camo, 3: camo_hazard
uniform int unit_index = 1;

instance uniform float orange_panel = 0.0;
instance uniform float chest_panel = 0.0;

varying vec3 part_position;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	v += 0.55 * value_noise(p);
	v += 0.30 * value_noise(p * 2.07 + vec3(11.3, 5.7, 3.1));
	v += 0.15 * value_noise(p * 4.19 + vec3(2.9, 17.1, 8.3));
	return v;
}

float seg_box(vec2 p, vec2 a, vec2 b, float half_w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - half_w;
}

int digit_mask(int d) {
	if (d == 0) return 63;  // a,b,c,d,e,f
	if (d == 1) return 6;   // b,c
	if (d == 2) return 91;  // a,b,d,e,g
	if (d == 3) return 79;  // a,b,c,d,g
	if (d == 4) return 102; // b,c,f,g
	if (d == 5) return 109; // a,c,d,f,g
	if (d == 6) return 125; // a,c,d,e,f,g
	if (d == 7) return 7;   // a,b,c
	if (d == 8) return 127; // all
	if (d == 9) return 111; // a,b,c,d,f,g
	return 0;
}

float draw_digit(vec2 p, int d) {
	int m = digit_mask(d);
	float w = 0.075;
	float dist = 10.0;
	if ((m & 1) != 0) dist = min(dist, seg_box(p, vec2(-0.26,  0.46), vec2( 0.26,  0.46), w)); // a
	if ((m & 2) != 0) dist = min(dist, seg_box(p, vec2( 0.28,  0.44), vec2( 0.28,  0.02), w)); // b
	if ((m & 4) != 0) dist = min(dist, seg_box(p, vec2( 0.28, -0.02), vec2( 0.28, -0.44), w)); // c
	if ((m & 8) != 0) dist = min(dist, seg_box(p, vec2(-0.26, -0.46), vec2( 0.26, -0.46), w)); // d
	if ((m & 16) != 0) dist = min(dist, seg_box(p, vec2(-0.28, -0.02), vec2(-0.28, -0.44), w)); // e
	if ((m & 32) != 0) dist = min(dist, seg_box(p, vec2(-0.28,  0.44), vec2(-0.28,  0.02), w)); // f
	if ((m & 64) != 0) dist = min(dist, seg_box(p, vec2(-0.24,  0.00), vec2( 0.24,  0.00), w)); // g
	return 1.0 - smoothstep(-0.015, 0.015, dist);
}

float unit_decal(vec3 pos, int idx) {
	// Upper-left chest armor plate (facing +Z in torso local space).
	if (pos.z < 0.16) return 0.0;
	vec2 uv_d = vec2((pos.x + 0.19) / 0.11, (pos.y - 0.42) / 0.09);
	if (abs(uv_d.x) > 1.35 || abs(uv_d.y) > 0.75) return 0.0;
	int tens = clamp(idx / 10, 0, 9);
	int ones = clamp(idx % 10, 0, 9);
	float d1 = draw_digit((uv_d - vec2(-0.44, 0.0)) * vec2(1.25, 1.15), tens);
	float d2 = draw_digit((uv_d - vec2( 0.44, 0.0)) * vec2(1.25, 1.15), ones);
	return max(d1, d2);
}

void vertex() {
	part_position = VERTEX;
}

void fragment() {
	vec3 tex = texture(base_texture, UV).rgb;
	vec3 mask_data = texture(paint_mask, UV).rgb;
	float paint = mask_data.r;
	float wear = mask_data.g;
	float seam = mask_data.b;

	float chest = chest_panel
		* step(0.16, part_position.y) * step(part_position.y, 0.34)
		* step(abs(part_position.x), 0.25) * step(0.12, part_position.z);

	vec3 coat = paint_color.rgb;
	bool is_camo = (pattern_mode == 2 || pattern_mode == 3);
	bool is_hazard = (pattern_mode == 1 || pattern_mode == 3);

	if (is_camo) {
		float n1 = fbm3(part_position * 5.2);
		float n2 = fbm3(part_position * 5.8 + vec3(4.1, 7.3, 1.9));
		vec3 dark_camo = paint_color.rgb * 0.56;
		coat = mix(coat, accent_color.rgb, smoothstep(0.46, 0.54, n1));
		coat = mix(coat, dark_camo, smoothstep(0.54, 0.62, n2));
	} else {
		// Two-tone secondary armor panels on shoulders/thighs.
		coat = mix(coat, accent_color.rgb, orange_panel * 0.85);
	}

	// Crisp racing/unit stripes on torso & secondary panels.
	if (pattern_mode == 0) {
		float torso_band = chest_panel * step(0.27, abs(part_position.x)) * step(abs(part_position.x), 0.35);
		float limb_stripe = orange_panel * step(0.42, fract(part_position.y * 5.0));
		float stripe = max(torso_band, limb_stripe * 0.65);
		coat = mix(coat, accent_color.rgb, stripe * 0.9);
		float pin = chest_panel * step(0.355, abs(part_position.x)) * step(abs(part_position.x), 0.375);
		coat = mix(coat, vec3(0.90, 0.88, 0.84), pin * 0.75);
	}

	// Hazard warning stripes on shoulder/thigh trim & lower torso skirt.
	if (is_hazard) {
		float diag = fract((part_position.x + part_position.y + part_position.z) * 11.5);
		float hz_band = step(0.5, diag);
		vec3 hz_col = mix(vec3(0.08, 0.08, 0.09), vec3(0.93, 0.72, 0.07), hz_band);
		float hz_zone = max(
			orange_panel * step(0.02, part_position.y),
			chest_panel * step(part_position.y, 0.14)
		);
		coat = mix(coat, hz_col, hz_zone * 0.92);
	}

	// Stencil unit number decal on upper-left chest plate.
	float decal = chest_panel * unit_decal(part_position, unit_index);
	vec3 decal_col = (pattern_mode == 1) ? vec3(0.95, 0.86, 0.65) : vec3(0.92, 0.91, 0.87);
	coat = mix(coat, decal_col, decal * 0.88);

	// Seam shading & micro-grain under the lacquer.
	float tex_luma = dot(tex, vec3(0.2126, 0.7152, 0.0722));
	vec3 painted = coat * mix(0.68, 1.0, seam) * clamp(tex_luma * 1.45 + 0.62, 0.62, 1.08);

	// Bare metal (joints, cables, under-frame) vs painted armor.
	vec3 bare_metal = tex * 0.92;
	vec3 surface_albedo = mix(bare_metal, painted, paint);

	// Edge wear & scratches sit ON TOP of the paint, revealing bright bare steel.
	vec3 scratch_steel = vec3(0.58, 0.60, 0.62) * mix(0.85, 1.05, tex_luma);
	float wear_amount = clamp(wear * paint * 1.15, 0.0, 1.0);
	ALBEDO = mix(surface_albedo, scratch_steel, wear_amount);

	// Separate roughness & metallic for paint vs bare metal vs chipped edges.
	float base_metallic = mix(0.78, 0.12, paint);
	float base_roughness = mix(0.36, 0.58, paint);
	METALLIC = mix(base_metallic, 0.85, wear_amount);
	ROUGHNESS = mix(base_roughness, 0.28, wear_amount);

	// The front vent stays luminous independently of the selected paint skin.
	EMISSION = vec3(1.0, 0.18, 0.015) * chest * 1.3;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
}
