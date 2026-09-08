// Masks a TextureRect to a rounded rectangle. `size` must match the control's
// pixel size (set from the script or left at the capsule column's 100x150).
shader_type canvas_item;

uniform float radius = 10.0;
uniform vec2 size = vec2(100.0, 150.0);

void fragment() {
	vec2 p = abs(UV * size - size * 0.5) - (size * 0.5 - radius);
	float d = length(max(p, vec2(0.0))) - radius;
	COLOR.a *= 1.0 - smoothstep(-0.75, 0.75, d);
}
