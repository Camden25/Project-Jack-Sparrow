shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled;

uniform vec4 outline_color : source_color = vec4(0.08, 0.35, 1.0, 1.0);
uniform float outline_width = 0.045;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
