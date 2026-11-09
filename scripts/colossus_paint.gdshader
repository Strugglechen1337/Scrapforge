shader_type spatial;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform vec4 paint_color : source_color = vec4(0.66, 0.64, 0.60, 1.0);
instance uniform float orange_panel = 0.0;
instance uniform float chest_panel = 0.0;
varying vec3 part_position;
void vertex() { part_position = VERTEX; }
void fragment() {
    vec3 tex = texture(base_texture, UV).rgb;
    float value = dot(tex, vec3(0.2126, 0.7152, 0.0722));
    float armor = smoothstep(0.035, 0.16, value);
    float chest = chest_panel * step(0.16, part_position.y) * step(part_position.y, 0.34) * step(abs(part_position.x), 0.25) * step(0.12, part_position.z);
    vec3 paint = mix(paint_color.rgb, vec3(0.85, 0.22, 0.025), max(orange_panel * 0.8, chest));
    // Preserve the original texture's scratches and seams as paint modulation.
    vec3 painted = paint * clamp(value * 2.4 + 0.22, 0.22, 1.0);
    ALBEDO = mix(tex * 0.8, painted, armor);
    NORMAL_MAP = texture(normal_texture, UV).rgb;
    METALLIC = 0.15;
    ROUGHNESS = 0.75;
}
