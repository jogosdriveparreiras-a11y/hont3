shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;

uniform sampler2D albedo_tex : source_color;
uniform float corner_radius = 0.055;
uniform vec4 modulate_color : source_color = vec4(1.0);

void fragment() {
	vec2 uv = UV;
	vec2 p = uv;
	// Signed distance to rounded rect in UV space [0,1]
	vec2 half_size = vec2(0.5) - vec2(corner_radius);
	vec2 q = abs(p - vec2(0.5)) - half_size;
	float dist = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	if (dist > 0.0) {
		discard;
	}
	vec4 tex = texture(albedo_tex, uv) * modulate_color;
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
}
