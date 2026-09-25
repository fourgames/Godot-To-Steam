shader_type canvas_item;
// Dithered gradient background with soft glows for the Steam art studio.
// Plain vec4 uniforms (no source_color): 2D in the Compatibility renderer
// works in sRGB, so colours pass through as written.

uniform vec2 rect_size = vec2(100.0);
uniform vec4 col_a = vec4(0.08, 0.08, 0.08, 1.0);
uniform vec4 col_b = vec4(0.08, 0.08, 0.08, 1.0);
uniform vec2 grad_from = vec2(0.0, 0.0);
uniform vec2 grad_to = vec2(0.0, 1.0);
uniform float radial = 0.0;
uniform vec3 glow[6];
uniform vec4 glow_color[6];
uniform int glow_count = 0;
uniform float vignette = 0.0;
uniform float noise = 1.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t;
	if (radial > 0.5) {
		// Radial: grad_from is the centre, |grad_to - grad_from| the radius (in height units).
		vec2 px = uv * rect_size / rect_size.y;
		vec2 c = grad_from * rect_size / rect_size.y;
		t = clamp(length(px - c) / length((grad_to - grad_from) * rect_size / rect_size.y), 0.0, 1.0);
	} else {
		vec2 d = grad_to - grad_from;
		t = clamp(dot(uv - grad_from, d) / dot(d, d), 0.0, 1.0);
	}
	t = t * t * (3.0 - 2.0 * t) * 0.5 + t * 0.5;
	vec3 col = mix(col_a.rgb, col_b.rgb, t);
	vec2 px = uv * rect_size;
	for (int i = 0; i < 6; i++) {
		if (i >= glow_count) {
			break;
		}
		vec2 gp = glow[i].xy * rect_size;
		float r = glow[i].z * rect_size.y;
		float dd = length(px - gp) / r;
		col += glow_color[i].rgb * glow_color[i].a * exp(-dd * dd * 2.2);
	}
	vec2 q = (uv - 0.5) * vec2(rect_size.x / rect_size.y, 1.0);
	col *= 1.0 - vignette * smoothstep(0.35, 1.25, length(q));
	col += (hash(FRAGCOORD.xy) + hash(FRAGCOORD.yx + 3.1) - 1.0) * noise / 255.0;
	COLOR = vec4(col, 1.0);
}
