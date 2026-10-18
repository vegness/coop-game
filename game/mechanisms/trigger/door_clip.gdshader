shader_type canvas_item;

varying vec2 world_pos;
uniform float clip_y : hint_range(-5000.0, 5000.0) = 0.0;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (world_pos.y < clip_y) {
		COLOR.a = 0.0;
	}
}
