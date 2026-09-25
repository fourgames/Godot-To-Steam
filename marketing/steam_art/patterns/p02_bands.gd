extends "res://marketing/steam_art/patterns/patterns_base.gd"
## P02 Speed Bands: diagonal rounded streaks rising to the right, like motion lines of an upload.


func _init() -> void:
	id = "P02"
	title = "Speed Bands"
	inspired_by = "diagonal rounded streaks"


func waves(c: CanvasItem, s: Vector2, spread: float, lift: float = 0.0) -> void:
	var ang := -0.38 * clampf(spread, 0.6, 1.1)
	var dir := Vector2(cos(ang), sin(ang))
	var nrm := Vector2(-dir.y, dir.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = 602
	var diag := s.length()
	var ctr := s * 0.5
	var stripes: Array = []
	for i in 18:
		var d := rng.randf_range(-0.5, 0.55) * diag * 0.55
		# Keep a clear band through the middle for the icon and name.
		var clear := s.y * (0.34 if s.y > s.x else 0.26)
		if d > -clear * 1.3 and d < clear:
			d = clear + absf(d) * 0.6 if d >= 0.0 else -clear * 1.3 - absf(d) * 0.4
		var layer: Array
		if d > 0.0:
			layer = LAYERS[clampi(int(d / (diag * 0.3) * 4.0), 0, 3)]
		else:
			layer = TOP_DEEP if rng.randf() < 0.6 else TOP_MID
		var p := ctr + nrm * d + dir * rng.randf_range(-0.45, 0.45) * diag
		if _mode == "hero" and p.x < s.x * 0.45 and p.y > s.y * 0.55:
			continue
		stripes.append([d, p, rng.randf_range(0.2, 0.6) * diag, s.y * rng.randf_range(0.03, 0.1), layer])
	stripes.sort_custom(func(a, b): return a[0] < b[0])
	for st in stripes:
		var length: float = st[2]
		var w: float = st[3]
		var far: Color = st[4][1]
		var crest: Color = st[4][0]
		c.draw_set_transform(st[1], ang, Vector2.ONE)
		var hl := length * 0.5 - w * 0.5
		c.draw_polygon(PackedVector2Array([Vector2(-hl, -w * 0.5), Vector2(hl, -w * 0.5), Vector2(hl, w * 0.5), Vector2(-hl, w * 0.5)]), PackedColorArray([far, crest, crest, far]))
		c.draw_circle(Vector2(-hl, 0), w * 0.5, far, true, -1.0, true)
		c.draw_circle(Vector2(hl, 0), w * 0.5, crest, true, -1.0, true)
		c.draw_line(Vector2(-hl * 0.2, -w * 0.5), Vector2(hl, -w * 0.5), Color(1, 1, 1, 0.14), maxf(1.0, s.y * 0.003), true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
