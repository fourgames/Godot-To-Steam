extends "res://marketing/steam_art/patterns/patterns_base.gd"
## P06 Topo Rings: nested topographic contour rings rising from the corners.


func _init() -> void:
	id = "P06"
	title = "Topo Rings"
	inspired_by = "topographic contours"


func _rings(c: CanvasItem, s: Vector2, center: Vector2, r0: float, count: int, outer: Color, inner: Color, phase: float) -> void:
	for k in count:
		var t := float(k) / count
		var pts := blob(center, r0 * (1.0 - t * 0.9), phase + k * 0.22, 0.7, 180)
		var col := outer.lerp(inner, t)
		fan(c, pts, center, col, col)
		var closed := pts.duplicate()
		closed.append(pts[0])
		c.draw_polyline(closed, Color(1, 1, 1, 0.06 + 0.1 * t), maxf(1.0, s.y * 0.003), true)


func waves(c: CanvasItem, s: Vector2, spread: float, lift: float = 0.0) -> void:
	var big := sqrt(s.x * s.y)
	var a := Vector2(s.x * 0.82, s.y * (0.98 - lift * 0.5))
	if _mode == "hero":
		a.x = s.x * 0.78
	_rings(c, s, a, big * 0.66, 13, BACK[1], FRONT[0], 0.6)
	_rings(c, s, Vector2(s.x * 0.06, -s.y * 0.08), big * 0.42, 7, TOP_DEEP[1], TOP_MID[0], 2.1)
