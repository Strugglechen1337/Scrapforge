shader_type spatial;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform vec4 paint_color : source_color = vec4(0.66, 0.64, 0.60, 1.0);
void fragment() {
    vec3 tex = texture(base_texture, UV).rgb;
    float value = max(max(tex.r, tex.g), tex.b);
    float armor = smoothstep(0.08, 0.4, value);
    ALBEDO = mix(tex * 0.65, paint_color.rgb * (0.45 + value * 0.65), armor);
    METALLIC = 0.15;
    ROUGHNESS = 0.75;
}
