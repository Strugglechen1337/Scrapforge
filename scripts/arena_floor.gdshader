shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D metal_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D metal_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D metal_rough : filter_linear_mipmap, repeat_enable;
uniform sampler2D concrete_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D concrete_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D concrete_rough : filter_linear_mipmap, repeat_enable;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
vec2 cell_offset(vec2 cell) { return vec2(hash(cell+vec2(17.0,31.0)),hash(cell+vec2(43.0,7.0)))*16.0; }
vec4 varied(sampler2D tex, vec2 uv) {
 vec2 cell=floor(uv*0.5), f=fract(uv*0.5);
 f=f*f*(3.0-2.0*f);
 vec2 dx=dFdx(uv), dy=dFdy(uv);
 vec4 a=textureGrad(tex,uv+cell_offset(cell),dx,dy);
 vec4 b=textureGrad(tex,uv+cell_offset(cell+vec2(1,0)),dx,dy);
 vec4 c=textureGrad(tex,uv+cell_offset(cell+vec2(0,1)),dx,dy);
 vec4 d=textureGrad(tex,uv+cell_offset(cell+vec2(1,1)),dx,dy);
 return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
void fragment() {
 vec2 warp=vec2(noise(UV*vec2(17.0,12.0)),noise(UV*vec2(13.0,19.0)+vec2(12.0,4.0)))-0.5;
 vec2 uv=UV*vec2(20.0,14.0)+warp*0.65;
 float m=smoothstep(0.22,0.78,noise(UV*vec2(9.0,6.0))*.75+noise(UV*vec2(24.0,17.0))*.25);
 vec3 a=varied(metal_color,uv).rgb;
 vec3 b=texture(concrete_color,uv*0.76+vec2(0.37,0.19)).rgb;
 float surface_mix=mix(0.65,0.90,m);
 float broad=noise(UV*vec2(7.0,5.0));
 float dirt=noise(UV*vec2(30.0,21.0));
 vec3 base=mix(a,b*0.65,surface_mix)*mix(0.22,0.32,broad);
 base=mix(base,vec3(0.08,0.065,0.055),smoothstep(0.61,0.83,dirt)*0.22);
 ALBEDO=max(base,vec3(0.045));
 METALLIC=mix(0.38,0.08,m);
 ROUGHNESS=clamp(mix(varied(metal_rough,uv).r,texture(concrete_rough,uv*.76+vec2(.37,.19)).r,surface_mix)+mix(-0.12,0.10,broad),0.23,0.95);
 NORMAL_MAP=mix(varied(metal_normal,uv).rgb,texture(concrete_normal,uv*.76+vec2(.37,.19)).rgb,surface_mix);
 NORMAL_MAP_DEPTH=0.65;
}
