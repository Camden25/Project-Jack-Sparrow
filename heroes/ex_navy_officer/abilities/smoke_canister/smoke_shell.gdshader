shader_type spatial;
render_mode depth_draw_opaque;

uniform vec4 shell_color : source_color = vec4(0.45, 0.45, 0.45, 1.0);

void fragment() {
	ALBEDO = shell_color.rgb;
}
