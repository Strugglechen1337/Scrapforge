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
    float red = step(0.4, tex.r) * step(0.10, tex.g) * step(0.08, tex.b) * step(tex.g * 1.5, tex.r);
    float optic = red * step(0.78, UV.x) * step(0.76, UV.y);
    tex = mix(tex, vec3(dot(tex, vec3(0.2126, 0.7152, 0.0722))) * vec3(0.65, 0.70, 0.75), red * (1.0 - optic) * 0.8);
    tex = mix(tex, vec3(0.20, 0.23, 0.27), 0.38);
    ALBEDO = mix(tex, vec3(1.0), instance_tint.r);
    EMISSION = mix(vec3(0.0), tex * vec3(1.8, 0.15, 0.08), optic);
    METALLIC = 0.3;
    ROUGHNESS = 0.42;
}
