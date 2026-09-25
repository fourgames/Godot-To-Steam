extends "res://marketing/steam_art/patterns/patterns_base.gd"
## P09 Folded Paper: hard creases, each facet lit or shaded like folded paper.


func _init() -> void:
	id = "P09"
	title = "Folded Paper"
	inspired_by = "creased paper facets"


func _folds(c: CanvasItem, s: Vector2, segs: int, base: float, amp: float, rise: float, phase: float, layer: Array, from_top: bool, edge_a: float) -> void:
	var pts := PackedVector2Array()
	for k in segs + 1:
		var t := float(k) / segs
		var up := (k + int(phase)) % 2 == 0
		var y := base + (-amp if up else amp) * (0.7 + 0.3 * sin(k * 1.7 + phase)) - rise * (t - 0.5)
		if _mode == "hero" and not from_top:
			y = lerpf(y, maxf(y, 0.92), 1.0 - smoothstep(0.35, 0.58, t))
		pts.append(Vector2(s.x * t, s.y * y))
	var far := 0.0 if from_top else s.y
	var crest: Color = layer[0]
	var dark: Color = layer[1]
	for k in segs:
		var lit := pts[k + 1].y < pts[k].y
		if from_top:
			lit = not lit
		var top_col := crest.darkened(0.05) if lit else dark.lerp(crest, 0.4)
		var bot_col := dark.lerp(crest, 0.2) if lit else dark
		fill_to(c, s, PackedVector2Array([pts[k], pts[k + 1]]), far, top_col, bot_col)
	if edge_a > 0.0:
		c.draw_polyline(pts, Color(1, 1, 1, edge_a), s.y * 0.004, true)


func waves(c: CanvasItem, s: Vector2, spread: float, lift: float = 0.0) -> void:
	var aspect := s.x / s.y
	_folds(c, s, int(clampf(aspect * 4.0, 4.0, 16.0)), 0.05 - lift * 0.3, 0.04, 0.45 * spread, 0.0, TOP_MID, true, 0.12)
	var bases := [0.7, 0.79, 0.88, 0.96]
	var amps := [0.07, 0.06, 0.05, 0.04]
	for li in 4:
		var segs := int(clampf(aspect * (2.5 + li), 3.0, 20.0))
		_folds(c, s, segs, bases[li] - lift * (1.0 - li * 0.15), amps[li], 0.5 * spread, float(li), LAYERS[li], false, EDGE_A[li])
