extends "res://marketing/steam_art/variant_base.gd"
## 10 Launch (HAELE 3D drama): the clover lifts off trailing a stream of the
## console's progress cells, over a blueprint of the app layout. White frame,
## heavy italic caps bottom-left.


func _init() -> void:
	id = "10"
	title = "Launch"
	inspired_by = "HAELE 3D"


func _bg(root: Control) -> void:
	L.add_bg(root, {
		"a": Color("#0d1220"), "b": Color("#07080c"),
		"from": Vector2(0.7, 0.3), "to": Vector2(0.7, 1.5), "radial": true,
		"glows": [[Vector2(0.72, 0.32), 0.5, Color(L.ACCENT, 0.18)]],
	})


## Faint blueprint of the app layout (window, sidebar, cards, depot rows).
func blueprint(c: CanvasItem, s: Vector2, origin: Vector2, k: float) -> void:
	var col := Color(L.CMD, 0.17)
	var w := maxf(1.0, s.y * 0.0018)
	var R := func(x: float, y: float, ww: float, hh: float) -> Rect2: return Rect2(origin + Vector2(x, y) * k, Vector2(ww, hh) * k)
	c.draw_rect(R.call(0, 0, 1440, 900), col, false, w)
	c.draw_line(origin + Vector2(260, 0) * k, origin + Vector2(260, 900) * k, col, w)
	for i in 10:
		c.draw_rect(R.call(24, 240 + i * 45, 200, 20), Color(col, col.a * 0.7), false, w)
	for r in [[290, 140, 760, 104], [290, 306, 84, 124], [390, 306, 660, 124], [290, 494, 760, 188], [290, 808, 760, 64], [1080, 16, 344, 868]]:
		c.draw_rect(R.call(r[0], r[1], r[2], r[3]), col, false, w)
	for i in 3:
		c.draw_rect(R.call(306, 542 + i * 44, 300, 34), Color(col, col.a * 0.7), false, w)
		c.draw_rect(R.call(616, 542 + i * 44, 180, 34), Color(col, col.a * 0.7), false, w)
	for i in 18:
		c.draw_line(origin + Vector2(1096, 90 + i * 44) * k, origin + Vector2(1096 + 120 + (i * 53) % 180, 90 + i * 44) * k, Color(col, col.a * 0.8), w)
	# Dimension ticks along the top.
	for i in 13:
		var x := origin.x + i * 120 * k
		c.draw_line(Vector2(x, origin.y - 30 * k), Vector2(x, origin.y - 14 * k), col, w)
	c.draw_line(origin + Vector2(0, -22) * k, origin + Vector2(1440, -22) * k, col, w)


## Trail of "depot packets" from a (far) to b (the rocket): square cells in
## the app's progress-bar green and Godot blue, dense and bright near b.
func trail(c: CanvasItem, a: Vector2, b: Vector2, cell: float, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4048520
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var ctrl := a.lerp(b, 0.5) + nrm * a.distance_to(b) * 0.1
	for i in 5:
		var off := nrm * (i - 2) * cell * 1.2
		c.draw_line(a.lerp(b, 0.2) + off, b.lerp(a, 0.18 + abs(i - 2) * 0.08) + off, Color(L.CMD, 0.09), cell * 0.1, true)
	for i in count:
		var t := pow(float(i) / count, 0.75)
		var p := a * (1 - t) * (1 - t) + ctrl * 2 * (1 - t) * t + b * t * t
		var spread := (1.0 - t) * cell * 2.2
		p += nrm * rng.randf_range(-spread, spread)
		var sz := cell * lerpf(0.4, 1.0, t) * rng.randf_range(0.8, 1.05)
		var col := Color("#5be37d") if rng.randf() < 0.62 else L.ACCENT_HI
		if t > 0.9:
			col = Color("#e8fff0")
		col.a = lerpf(0.18, 1.0, t)
		if t > 0.55:
			L.rrect(c, Rect2(p - Vector2(sz, sz), Vector2(sz, sz) * 2.0), sz * 0.5, Color(col, col.a * 0.12))
		L.rrect(c, Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), sz * 0.16, col)


func rocket(c: CanvasItem, r: Rect2) -> void:
	L.glow(c, r.get_center(), r.size.x * 1.1, Color(L.ACCENT, 0.45), 30)
	var tex := L.clover_tex(int(r.size.x))
	L.soft(c, func(cc, off, tint): cc.draw_texture_rect(tex, Rect2(r.position + off, r.size), false, tint), r.size.x * 0.04, 0.5, Vector2(0, r.size.x * 0.03))
	c.draw_texture_rect(tex, r, false)


func mark(kind: String) -> Dictionary:
	var spec := {
		"lines": L.words(["GODOT TO", "STEAM"], Color.WHITE),
		"font": "Inter_18pt-ExtraBoldItalic", "track": -0.01, "icon": "none",
		"layout": "h", "halign": "left", "valign": "bottom", "line_gap": 0.16,
	}
	if kind == "library_logo":
		spec.icon = "clover"
		spec.icon_scale = 1.0
		spec.gap = 0.3
		spec.halign = "center"
		spec.valign = "center"
	return spec


func background(root: Control, s: Vector2, mode: String) -> void:
	L.add_bg(root, {
		"a": Color("#0f1628"), "b": Color("#06070b"),
		"from": Vector2(0.64, 0.28), "to": Vector2(0.64, 1.5), "radial": true,
		"glows": [[Vector2(0.64, 0.28), 0.5, Color(L.ACCENT, 0.25)]],
	})
	L.add_draw(root, func(c: Control) -> void:
		var k := s.y * 0.9 / 900.0
		blueprint(c, s, Vector2(s.x * 0.5 - 720 * k, s.y * 0.08), k)
		var cell := s.y * 0.04
		# Focal point inside the centre safe area.
		var top := Vector2(s.x * 0.64, s.y * 0.3)
		trail(c, Vector2(s.x * 0.4, s.y * 1.08), top, cell, 100)
		# The upload lands: a ring and a check where the trail ends.
		L.glow(c, top, s.y * 0.42, Color("#dff3ff", 0.28), 36)
		var ring := s.y * 0.1
		c.draw_circle(top, ring, Color("#5be37d", 0.95), true, -1.0, true)
		c.draw_polyline(PackedVector2Array([top + Vector2(-ring * 0.45, 0), top + Vector2(-ring * 0.1, ring * 0.35), top + Vector2(ring * 0.5, -ring * 0.35)]), Color("#06270f"), ring * 0.18, true)
		c.draw_arc(top, ring * 1.7, 0, TAU, 128, Color("#dff3ff", 0.22), s.y * 0.004, true)
		if mode == "hero":
			L.calm_corner(c, s, Color(0.03, 0.035, 0.05, 0.85)))


func capsule(root: Control, kind: String, s: Vector2) -> void:
	_bg(root)
	var is_tall := tall(s)
	var rocket_r: Rect2
	var trail_from: Vector2
	var logo_r: Rect2
	var cell: float
	if kind == "small":
		var side := s.y * 0.56
		rocket_r = Rect2(Vector2(s.x * 0.86 - side * 0.5, s.y * 0.1), Vector2(side, side))
		trail_from = Vector2(s.x * 0.74, s.y * 1.08)
		logo_r = fr(s, 0.04, 0.1, 0.66, 0.8)
		cell = s.y * 0.075
	elif is_tall:
		var side := s.x * 0.34
		rocket_r = Rect2(Vector2(s.x * 0.62 - side * 0.5, s.y * 0.1), Vector2(side, side))
		trail_from = Vector2(s.x * 0.2, s.y * 0.72)
		logo_r = fr(s, 0.08, 0.66, 0.84, 0.26)
		cell = s.x * 0.04
	else:
		var side := s.y * 0.42
		rocket_r = Rect2(Vector2(s.x * 0.78 - side * 0.5, s.y * 0.1), Vector2(side, side))
		trail_from = Vector2(s.x * 0.5, s.y * 1.08)
		logo_r = fr(s, 0.055, 0.4, 0.5, 0.48)
		cell = s.y * 0.05
	var spec := mark(kind)
	spec["shadow"] = [0.2, 0.5]
	L.add_draw(root, func(c: Control) -> void:
		var k := (s.y if not is_tall else s.x * 0.62) * 1.0 / 900.0
		blueprint(c, s, Vector2(s.x * (0.36 if not is_tall else 0.08), s.y * 0.1), k)
		trail(c, trail_from, rocket_r.get_center() + Vector2(0, rocket_r.size.y * 0.35), cell, 70 if kind != "small" else 40)
		rocket(c, rocket_r)
		L.lockup(c, logo_r, spec)
		var bw := s.y * (0.012 if not is_tall else 0.008)
		if kind == "small":
			bw = s.y * 0.016
		c.draw_rect(Rect2(Vector2(bw, bw) * 0.5, s - Vector2(bw, bw)), Color.WHITE, false, bw, true))
