shader_type canvas_item;

varying vec2 world_pos;
uniform float clip_x : hint_range(-5000.0, 5000.0) = 0.0;
uniform bool from_left = true;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	bool hidden = from_left ? (world_pos.x < clip_x) : (world_pos.x > clip_x);
	if (hidden) {
		COLOR.a = 0.0;
	}
}
