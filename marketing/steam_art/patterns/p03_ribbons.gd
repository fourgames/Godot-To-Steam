extends "res://marketing/steam_art/patterns/patterns_base.gd"
## P03 Ribbons: flowing ribbons that swell and pinch as they rise across the frame.


func _init() -> void:
	id = "P03"
	title = "Ribbons"
	inspired_by = "flowing ribbons"


func _ribbon(c: CanvasItem, s: Vector2, r: Array, spread: float, lift: float, f: float) -> void:
	var n := 140
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var cy: float = r[0] - lift + r[1] * sin(TAU * r[2] * f * t + r[3]) - 0.22 * spread * (t - 0.5)
		if _mode == "hero" and r[0] > 0.5:
			cy += 0.1 * (1.0 - smoothstep(0.3, 0.6, t))
		var th: float = r[4] * (0.12 + 0.88 * (0.5 + 0.5 * sin(TAU * 0.55 * f * t + r[3] * 1.3)))
		top.append(Vector2(s.x * t, s.y * (cy - th * 0.5)))
		bot.append(Vector2(s.x * t, s.y * (cy + th * 0.5)))
	var layer: Array = r[5]
	var crest: Color = layer[0]
	var far: Color = layer[1]
	for i in n:
		c.draw_polygon(PackedVector2Array([top[i], top[i + 1], bot[i + 1], bot[i]]), PackedColorArray([crest, crest, Color(far, 0.9), Color(far, 0.9)]))
	c.draw_polyline(top, Color(1, 1, 1, r[6]), s.y * 0.004, true)


func waves(c: CanvasItem, s: Vector2, spread: float, lift: float = 0.0) -> void:
	var f := clampf(s.x / s.y / 2.1, 0.5, 2.2)
	var ribbons := [
		[0.12, 0.05, 0.8, 1.0, 0.16, TOP_DEEP, 0.08],
		[0.03, 0.04, 1.0, 2.5, 0.12, TOP_MID, 0.14],
		[0.72, 0.05, 0.7, 0.3, 0.2, BACK, 0.12],
		[0.8, 0.06, 0.9, 2.1, 0.17, MID, 0.2],
		[0.88, 0.05, 1.1, 4.0, 0.14, BRIGHT, 0.32],
		[0.96, 0.04, 1.4, 1.0, 0.11, FRONT, 0.4],
	]
	for r in ribbons:
		var rr: Array = r.duplicate()
		if _mode == "hero" and r[0] > 0.5:
			rr[0] = r[0] + 0.04
		_ribbon(c, s, rr, spread, lift if r[0] > 0.5 else lift * 0.3, f)
