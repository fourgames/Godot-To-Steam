extends "res://marketing/steam_art/variant_base.gd"
## 08 Upload Starfield (HudSight): a navy-to-indigo sky full of tiny glyphs
## from the app (upload arrows, checkmarks, progress cells, reticles),
## a few large reticles and a semibold wordmark.


func _init() -> void:
	id = "08"
	title = "Upload Starfield"
	inspired_by = "HudSight"


func _bg(root: Control) -> void:
	L.add_bg(root, {
		"a": Color("#111a33"), "b": Color("#1e1b4b"),
		"from": Vector2(0.1, 0.0), "to": Vector2(0.9, 1.0),
		"glows": [[Vector2(0.72, 0.32), 0.7, Color("#3d3f9e", 0.25)], [Vector2(0.25, 0.7), 0.6, Color("#1d4f9c", 0.3)]],
	})


func _glyph(c: CanvasItem, kind: int, p: Vector2, sz: float, col: Color) -> void:
	var w := maxf(1.0, sz * 0.14)
	match kind:
		0: # crosshair plus
			c.draw_line(p - Vector2(sz * 0.5, 0), p + Vector2(sz * 0.5, 0), col, w, true)
			c.draw_line(p - Vector2(0, sz * 0.5), p + Vector2(0, sz * 0.5), col, w, true)
		1: # upload chevron
			c.draw_polyline(PackedVector2Array([p + Vector2(-sz * 0.4, sz * 0.2), p + Vector2(0, -sz * 0.25), p + Vector2(sz * 0.4, sz * 0.2)]), col, w, true)
		2: # check
			c.draw_polyline(PackedVector2Array([p + Vector2(-sz * 0.4, 0), p + Vector2(-sz * 0.1, sz * 0.3), p + Vector2(sz * 0.45, -sz * 0.3)]), col, w, true)
		3: # progress cell
			c.draw_rect(Rect2(p - Vector2(sz, sz) * 0.22, Vector2(sz, sz) * 0.44), col)
		4: # star dot
			c.draw_circle(p, sz * 0.12, col, true, -1.0, true)
		5: # corner brackets (HudSight-style reticle)
			var h := sz * 0.45
			var l := sz * 0.2
			for sx in [-1, 1]:
				for sy in [-1, 1]:
					var q := p + Vector2(h * sx, h * sy)
					c.draw_line(q, q - Vector2(l * sx, 0), col, w, true)
					c.draw_line(q, q - Vector2(0, l * sy), col, w, true)


## Scatter glyphs, keeping out of avoid (the logo area). Only crosshair
## pluses, upload chevrons, checkmarks and progress cells.
func stars(c: CanvasItem, s: Vector2, avoid: Rect2, density: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1477830
	var n := int(s.x * s.y / pow(s.y * 0.075, 2.0) * density * 0.4)
	var placed: Array[Vector2] = []
	var min_gap := s.y * 0.06
	for i in n * 3:
		if placed.size() >= n:
			break
		var depth := rng.randf()
		var sz := s.y * lerpf(0.014, 0.045, depth * depth)
		var p := Vector2(rng.randf_range(sz, s.x - sz), rng.randf_range(sz, s.y - sz))
		if avoid.has_point(p):
			continue
		var close := false
		for q in placed:
			if q.distance_to(p) < min_gap:
				close = true
				break
		if close:
			continue
		placed.append(p)
		var kind := 0 if rng.randf() < 0.45 else 4
		var a := lerpf(0.12, 0.35, depth)
		var col := Color("#cfe3ff", a) if rng.randf() < 0.6 else Color("#5aa0dc", a)
		_glyph(c, kind, p, sz, col)


func _outline(c: CanvasItem, center: Vector2, size: float, width: float, a: float) -> void:
	var box := L.clover_box()
	var pts := PackedVector2Array()
	for p in L.clover_poly():
		pts.append(center + (p - box.get_center()) * (size / box.size.x))
	pts.append(pts[0])
	c.draw_polyline(pts, Color("#8f8cff", a), width, true)


func background(root: Control, s: Vector2, mode: String) -> void:
	_bg(root)
	L.add_draw(root, func(c: Control) -> void:
		var calm := Rect2(0, s.y * 0.5, s.x * 0.4, s.y * 0.5) if mode == "hero" else Rect2()
		stars(c, s, calm, 1.3 if mode == "hero" else 0.9)
		# A few big reticles in the centre band.
		for p in [Vector2(0.5, 0.35), Vector2(0.66, 0.6), Vector2(0.8, 0.28)]:
			_glyph(c, 5, s * p, s.y * 0.14, Color("#8fb6ff", 0.22))
			_glyph(c, 0, s * p, s.y * 0.05, Color("#8fb6ff", 0.35))
		if mode == "hero":
			L.calm_corner(c, s, Color(0.07, 0.09, 0.18, 0.6)))


func mark(kind: String) -> Dictionary:
	var spec := {
		"lines": L.words(["Godot To Steam"], Color.WHITE),
		"font": "Inter-Bold", "track": -0.02, "icon": "clover",
		"icon_scale": 2.3, "gap": 0.36, "layout": "h",
	}
	if kind == "small":
		spec.lines = L.words(["Godot To", "Steam"], Color.WHITE)
		spec.font = "Inter-SemiBold"
		spec.icon_scale = 1.2
		spec.gap = 0.26
		spec.font = "Inter-Bold"
	elif kind in ["vertical", "library_capsule"]:
		spec.lines = L.words(["Godot To", "Steam"], Color.WHITE)
		spec.layout = "v"
		spec.icon_scale = 1.35
		spec.gap = 0.45
	return spec


func capsule(root: Control, kind: String, s: Vector2) -> void:
	_bg(root)
	var r: Rect2
	if kind == "small":
		r = fr(s, 0.04, 0.08, 0.92, 0.84)
	elif tall(s):
		r = fr(s, 0.08, 0.2, 0.84, 0.6)
	else:
		r = fr(s, 0.06, 0.18, 0.88, 0.64)
	var spec := mark(kind)
	L.add_draw(root, func(c: Control) -> void:
		var b := L.lockup(c, r, spec.merged({"dry": true}))
		stars(c, s, b.grow(s.y * 0.04), 0.7 if kind != "small" else 0.4)
		if kind != "small":
			# A few larger reticles as the "hero" glyphs.
			for p in [Vector2(0.9, 0.2), Vector2(0.09, 0.8), Vector2(0.88, 0.82)]:
				if not b.grow(s.y * 0.06).has_point(s * p):
					_glyph(c, 5, s * p, s.y * 0.12, Color("#8fb6ff", 0.3))
					_glyph(c, 0, s * p, s.y * 0.04, Color("#8fb6ff", 0.45))
		c.draw_set_transform(b.get_center(), 0.0, Vector2(1.0, b.size.y / b.size.x))
		L.glow(c, Vector2.ZERO, b.size.x * 0.62, Color("#0b0f26", 0.7), 24)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var icon_c := Vector2(b.position.x + b.size.y * 0.5, b.get_center().y) if not tall(s) else Vector2(b.get_center().x, b.position.y + b.size.x * 0.25)
		L.glow(c, icon_c, s.x * 0.3, Color("#3b5bdb", 0.25), 30)
		L.lockup(c, r, spec))
