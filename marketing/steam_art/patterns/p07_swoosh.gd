extends "res://marketing/steam_art/patterns/patterns_base.gd"
## P07 Swoosh: sweeping crescents that launch from the bottom-left up to the right.


func _init() -> void:
	id = "P07"
	title = "Swoosh"
	inspired_by = "sweeping launch crescents"


func _bez(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * u * u + p1 * 2.0 * u * t + p2 * t * t


func _crescent(c: CanvasItem, s: Vector2, p0: Vector2, c_out: Vector2, c_in: Vector2, p2: Vector2, layer: Array, edge_a: float) -> void:
	var n := 120
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		outer.append(_bez(p0, c_out, p2, t))
		inner.append(_bez(p0, c_in, p2, t))
	var crest: Color = layer[0]
	var far: Color = layer[1]
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		c.draw_polygon(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]]),
			PackedColorArray([far.lerp(crest, t0), far.lerp(crest, t1), far, far]))
	c.draw_polyline(outer, Color(1, 1, 1, edge_a), s.y * 0.004, true)


func waves(c: CanvasItem, s: Vector2, spread: float, lift: float = 0.0) -> void:
	# Top: one broad sweep hanging from the top edge.
	_crescent(c, s, Vector2(-s.x * 0.05, s.y * (0.34 - lift * 0.3)), Vector2(s.x * 0.45, -s.y * 0.02), Vector2(s.x * 0.45, -s.y * 0.3), Vector2(s.x * 1.05, -s.y * 0.05), TOP_DEEP, 0.1)
	_crescent(c, s, Vector2(-s.x * 0.05, s.y * (0.14 - lift * 0.3)), Vector2(s.x * 0.55, -s.y * 0.05), Vector2(s.x * 0.55, -s.y * 0.25), Vector2(s.x * 1.05, -s.y * 0.1), TOP_MID, 0.16)
	var ends := [0.38, 0.52, 0.66, 0.8]
	var thick := [0.3, 0.24, 0.19, 0.15]
	for li in 4:
		var start_x := -0.08 + (0.4 if _mode == "hero" else 0.0)
		var p0 := Vector2(s.x * start_x, s.y * 1.04)
		var p2 := Vector2(s.x * 1.06, s.y * (ends[li] + 0.25 * (1.0 - spread) - lift))
		var co := Vector2(s.x * 0.52, s.y * (0.98 - li * 0.02 - lift * 0.5))
		var ci := co + Vector2(0, s.y * thick[li])
		_crescent(c, s, p0, co, ci, p2, LAYERS[li], EDGE_A[li])
