shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D walk_vat : filter_nearest, repeat_disable;
uniform float vat_range = 0.616054864;
uniform float vat_rows = 7.0;
uniform float vat_height = 224.0;
uniform float walk_duration = 0.65;

varying vec4 instance_tint;
void vertex() {
    float phase = fract(TIME / walk_duration + float(INSTANCE_ID) * 0.173);
    float frame = floor(phase * 32.0);
    vec3 encoded = textureLod(walk_vat, UV2 + vec2(0.0, frame * vat_rows / vat_height), 0.0).rgb;
    VERTEX += (encoded * 2.0 - 1.0) * vat_range;
    instance_tint = COLOR;
}
void fragment() {
    vec3 tex = texture(albedo_texture, UV).rgb;
    float red = step(0.08, tex.r) * step(tex.g * 1.5, tex.r) * step(tex.b * 1.25, tex.r);
    ALBEDO = mix(tex, vec3(1.0), instance_tint.r);
    EMISSION = mix(vec3(0.0), tex * vec3(1.8, 0.15, 0.08), red);
    METALLIC = 0.6;
    ROUGHNESS = 0.55;
}
