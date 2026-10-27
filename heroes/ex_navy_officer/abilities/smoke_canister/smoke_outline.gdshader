shader_type spatial;
render_mode unshaded, cull_front, blend_mix, depth_draw_never, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.15, 0.85, 1.0, 1.0);
uniform float outline_width = 0.035;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
