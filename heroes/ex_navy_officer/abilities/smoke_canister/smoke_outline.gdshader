shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.08, 0.08, 1.0);
uniform float outline_width = 2.0;

void fragment() {
	float center_alpha = texture(TEXTURE, UV).a;
	float neighbor_alpha = 0.0;
	vec2 sample_step = TEXTURE_PIXEL_SIZE * outline_width;

	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			if (x == 0 && y == 0) {
				continue;
			}

			vec2 sample_uv = clamp(
				UV + vec2(float(x), float(y)) * sample_step,
				vec2(0.0),
				vec2(1.0)
			);
			neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, sample_uv).a);
		}
	}

	float edge_alpha = max(neighbor_alpha - center_alpha, 0.0);
	COLOR = vec4(outline_color.rgb, edge_alpha * outline_color.a);
}
