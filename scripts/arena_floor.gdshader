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

// Stable per-plate wear: no low-frequency gradients or blurred stains.
float plate_tone(vec2 id) {
    return fract(sin(dot(id, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
    vec2 uv = UV * vec2(10.0, 6.875);
    vec2 plate = floor(UV * vec2(40.0, 27.5));
    float variation = mix(0.94, 1.06, plate_tone(plate));
    vec3 detail = texture(floor_mask, UV * vec2(38.0, 26.0)).rgb;
    vec3 metal = texture(metal_color, uv).rgb * brightness * variation;
    vec3 concrete = texture(concrete_color, uv * 0.5 + vec2(0.13, 0.27)).rgb;
    ALBEDO = max(metal * mix(0.96, 1.04, detail.g) + concrete * 0.001, vec3(0.020));
    float rough = texture(metal_rough, uv).r;
    METALLIC = 0.4;
    ROUGHNESS = clamp(rough + (detail.g - 0.5) * 0.08, 0.55, 0.95);
    NORMAL_MAP = texture(metal_normal, uv).rgb;
    NORMAL_MAP_DEPTH = normal_depth;
}
