shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool hover = false;
varying vec4 instance_tint;
void vertex() {
    float phase = TIME * 8.0 + float(INSTANCE_ID) * 0.77;
    if (hover) {
        VERTEX.y += 0.14 + sin(phase * 0.5) * 0.045;
        VERTEX.x += VERTEX.y * sin(phase * 0.4) * 0.04;
    } else {
        float side = sign(VERTEX.x);
        float motion = UV2.x;
        float step_phase = phase + sign(VERTEX.z) * 2.0 + side * 1.57;
        VERTEX.z += sin(step_phase) * 0.12 * motion;
        VERTEX.y += max(0.0, cos(step_phase)) * 0.11 * motion;
    }
    instance_tint = COLOR;
}
void fragment() {
    vec3 tex = texture(albedo_texture, UV).rgb;
    float red = step(0.12, tex.r) * step(tex.g * 1.5, tex.r) * step(tex.b * 1.4, tex.r);
    tex = mix(tex, vec3(dot(tex, vec3(0.2126, 0.7152, 0.0722))) * vec3(0.65, 0.72, 0.80), red);
    ALBEDO = mix(tex, vec3(1.0), instance_tint.r);
    EMISSION = vec3(0.0);
    METALLIC = 0.35;
    ROUGHNESS = 0.46;
}
