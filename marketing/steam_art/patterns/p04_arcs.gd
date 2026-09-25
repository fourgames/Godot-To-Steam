extends "res://marketing/steam_art/patterns/patterns_base.gd"
## P04 Horizon Arcs: clean concentric arcs like a planet horizon, peaking right of centre.


func _init() -> void:
	id = "P04"
	title = "Horizon Arcs"
	inspired_by = "concentric horizon arcs"


func _arc_edge(s: Vector2, cx: float, cy: float, r: float, below: bool) -> PackedVector2Array:
	var edge := PackedVector2Array()
	for i in 161:
		var x := s.x * (-0.02 + 1.04 * i / 160.0)
		var dx := x - cx
		var h := sqrt(maxf(r * r - dx * dx, 0.0))
		edge.append(Vector2(x, cy - h if below else cy + h))
	return edge


func waves(c: CanvasItem, s: Vector2, spread: float, lift: float = 0.0) -> void:
	var peak_x := s.x * (0.78 if s.x > s.y else 0.7)
	# Top-left: two arcs of a huge circle above the frame.
	var tc := Vector2(s.x * 0.05, -s.y * 2.2)
	for i in 2:
		var r: float = s.y * (2.2 + [0.4, 0.28][i]) + s.x * 0.08
		var e := _arc_edge(s, tc.x, tc.y, r, false)
		fill_to(c, s, e, 0.0, [TOP_DEEP, TOP_MID][i][0], [TOP_DEEP, TOP_MID][i][1])
		edge_line(c, s, e, 0.12)
	# Bottom: horizon bands of one big circle below the frame.
	var R := s.y * 2.6 + s.x * 0.35
	var cy := s.y + R
	var bases := [0.62, 0.73, 0.84, 0.93]
	for li in 4:
		var top_y: float = bases[li] - lift * (1.0 - li * 0.15)
		if _mode == "hero":
			top_y += 0.06
		var r: float = cy - s.y * top_y
		var e := _arc_edge(s, peak_x, cy, r, true)
		fill_to(c, s, e, s.y, LAYERS[li][0], LAYERS[li][1])
		edge_line(c, s, e, EDGE_A[li])
	# Faint orbit lines above the horizon.
	for k in 4:
		var r: float = cy - s.y * (0.46 - k * 0.07 - lift)
		var e := _arc_edge(s, peak_x, cy, r, true)
		c.draw_polyline(e, Color(L.CLOVER_B, 0.1 - k * 0.018), maxf(1.0, s.y * 0.0025), true)
