extends "res://marketing/steam_art/waves/waves_base.gd"
## Background-pattern studies on the original Depot Waves (06). Palette,
## icon, wordmark and layout stay exactly as in 06; each pattern only
## overrides waves() to draw different shapes behind them.

## Original 06 layer colours, back to front: [crest, far].
const BACK := [Color("#1b4f9c"), Color("#0b1740")]
const MID := [Color("#2f7fd0"), Color("#123a7a")]
const BRIGHT := [Color("#48baff"), Color("#1f6fb0")]
const FRONT := [Color("#5fd6e8"), Color("#1f7f9a")]
const TOP_DEEP := [Color("#1f3f86"), Color("#0e1a45")]
const TOP_MID := [Color("#2b62b8"), Color("#152a66")]
const LAYERS := [BACK, MID, BRIGHT, FRONT]
const EDGE_A := [0.12, 0.22, 0.35, 0.4]


## Fill from a crest polyline to the far edge (s.y = bottom, 0 = top).
func fill_to(c: CanvasItem, s: Vector2, edge: PackedVector2Array, far: float, crest: Color, far_col: Color) -> void:
	for i in edge.size() - 1:
		var e0 := Vector2(edge[i].x, clampf(edge[i].y, 0.0, s.y))
		var e1 := Vector2(edge[i + 1].x, clampf(edge[i + 1].y, 0.0, s.y))
		var flat0 := absf(e0.y - far) < 0.5
		var flat1 := absf(e1.y - far) < 0.5
		if (flat0 and flat1) or absf(e1.x - e0.x) < 0.01:
			continue
		if flat0:
			c.draw_polygon(PackedVector2Array([e0, e1, Vector2(e1.x, far)]), PackedColorArray([far_col, crest, far_col]))
		elif flat1:
			c.draw_polygon(PackedVector2Array([e0, e1, Vector2(e0.x, far)]), PackedColorArray([crest, far_col, far_col]))
		else:
			c.draw_polygon(PackedVector2Array([e0, e1, Vector2(e1.x, far), Vector2(e0.x, far)]), PackedColorArray([crest, crest, far_col, far_col]))


func edge_line(c: CanvasItem, s: Vector2, edge: PackedVector2Array, a: float) -> void:
	if a > 0.0:
		c.draw_polyline(edge, Color(1, 1, 1, a), s.y * 0.004, true)


## Star-shaped polygon filled as a fan: centre colour to rim colour.
func fan(c: CanvasItem, pts: PackedVector2Array, center: Vector2, c_col: Color, rim_col: Color) -> void:
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		if (a - center).cross(b - center) == 0.0:
			continue
		c.draw_polygon(PackedVector2Array([center, a, b]), PackedColorArray([c_col, rim_col, rim_col]))


## Organic closed curve around center (wobbly circle).
func blob(center: Vector2, r: float, seed_phase: float, wobble: float = 1.0, n: int = 120) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var th := TAU * i / n
		var k := 1.0 + wobble * (0.12 * sin(2.0 * th + seed_phase) + 0.07 * sin(3.0 * th + seed_phase * 1.7) + 0.035 * sin(5.0 * th + seed_phase * 0.6))
		pts.append(center + Vector2(cos(th), sin(th)) * r * k)
	return pts


## The original 06 crest height (fraction of s.y) for layer w at t.
func crest_y(w: Array, t: float, f: float, spread: float, lift: float, from_top: bool) -> float:
	var base: float = w[0] - lift * (0.3 if from_top else 1.0)
	var amp: float = w[1]
	var freq: float = w[2] * f
	var phase: float = w[3]
	return base + amp * sin(TAU * freq * t + phase) + amp * 0.35 * sin(TAU * freq * 2.3 * t + phase * 1.7) + w[4] * spread * (t - 0.5)
