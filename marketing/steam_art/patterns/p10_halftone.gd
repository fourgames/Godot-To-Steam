extends "res://marketing/steam_art/patterns/patterns_base.gd"
## P10 Halftone Waves: the original waves rendered as a dot matrix; dots grow with depth.


func _init() -> void:
	id = "P10"
	page_blur = 24.0
	title = "Halftone Waves"
	inspired_by = "dot-matrix waves"


func waves(c: CanvasItem, s: Vector2, spread: float, lift: float = 0.0) -> void:
	var f := clampf(s.x / s.y / 2.1, 0.5, 2.2)
	var g := minf(s.x, s.y) * (0.06 if _kind == "small" else 0.03)
	if _mode == "hero":
		g = s.y * 0.02
	var bottom: Array = cfg.bottom
	var top: Array = cfg.top
	var row := 0
	var y := g * 0.5
	while y < s.y + g:
		var x := g * 0.5 + (g * 0.5 if row % 2 == 1 else 0.0)
		var yf := y / s.y
		while x < s.x + g:
			var t := x / s.x
			var drawn := false
			for li in range(bottom.size() - 1, -1, -1):
				var cy := crest_y(bottom[li], t, f, spread, lift, false)
				if _mode == "hero":
					cy = lerpf(cy, maxf(cy, 0.86 + (bottom[li][0] - 0.72) * 0.5), 1.0 - smoothstep(0.35, 0.55, t))
				if yf >= cy:
					var depth := yf - cy
					var col: Color = bottom[li][5].lerp(bottom[li][6], clampf(depth * 3.0, 0.0, 1.0))
					c.draw_circle(Vector2(x, y), g * 0.5 * clampf(0.42 + depth * 3.4, 0.42, 0.98), col.lightened(0.08), true, -1.0, true)
					drawn = true
					break
			if not drawn:
				for li in range(top.size() - 1, -1, -1):
					var cy := crest_y(top[li], t, f, spread, lift, true)
					if yf <= cy:
						var depth := cy - yf
						var col: Color = top[li][5].lerp(top[li][6], clampf(depth * 3.0, 0.0, 1.0))
						c.draw_circle(Vector2(x, y), g * 0.5 * clampf(0.42 + depth * 3.4, 0.42, 0.95), col, true, -1.0, true)
						drawn = true
						break
			if not drawn:
				c.draw_circle(Vector2(x, y), g * 0.08, Color("#3b5bdb", 0.12), true, -1.0, true)
			x += g
		y += g * 0.87
		row += 1
