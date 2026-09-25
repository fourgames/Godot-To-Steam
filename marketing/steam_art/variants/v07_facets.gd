extends "res://marketing/steam_art/variant_base.gd"
## 07 Faceted Blue (Soundpad): bold angled shards in Godot-blue shades, a
## huge glossy clover bleeding off the left edge (like Soundpad's giant icon)
## and a heavy wordmark on the right.

## Shards in unit space: [points, colour]. Drawn back to front.
const SHARDS := [
	[[Vector2(0, 0), Vector2(0.58, 0), Vector2(0.36, 1), Vector2(0, 1)], Color("#173460")],
	[[Vector2(0.58, 0), Vector2(1, 0), Vector2(1, 0.34), Vector2(0.64, 0.56)], Color("#1f4478")],
	[[Vector2(0.36, 1), Vector2(0.64, 0.56), Vector2(1, 0.34), Vector2(1, 1)], Color("#122a4d")],
	[[Vector2(0.64, 0.56), Vector2(1, 0.34), Vector2(1, 0.64)], Color("#26528c")],
	[[Vector2(0, 0), Vector2(0.32, 0), Vector2(0, 0.46)], Color("#1c3f6f")],
	[[Vector2(0.45, 0), Vector2(0.52, 0), Vector2(0.31, 1), Vector2(0.24, 1)], Color("#1f467a")],
	[[Vector2(0.78, 1), Vector2(1, 0.8), Vector2(1, 1)], Color("#0f2340")],
	[[Vector2(0, 0.62), Vector2(0.18, 1), Vector2(0, 1)], Color("#132e55")],
]


func _init() -> void:
	id = "07"
	title = "Faceted Blue"
	inspired_by = "Soundpad"


func facets(c: CanvasItem, s: Vector2) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, s), Color("#15315a"))
	for sh in SHARDS:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var col: Color = sh[1]
		for p in sh[0]:
			pts.append(p * s)
			cols.append(col.lightened(0.14 * (1.0 - p.y)).darkened(0.12 * p.x))
		c.draw_polygon(pts, cols)
		var closed := pts.duplicate()
		closed.append(pts[0])
		c.draw_polyline(closed, Color(1, 1, 1, 0.07), maxf(1.0, s.y * 0.003), true)


func _clover(c: CanvasItem, r: Rect2, rot: float) -> void:
	var tex := L.clover_tex(int(r.size.x))
	var local := Rect2(-r.size * 0.5, r.size)
	L.glow(c, r.get_center(), r.size.x * 0.7, Color("#48baff", 0.25), 30)
	c.draw_set_transform(r.get_center(), rot, Vector2.ONE)
	L.soft(c, func(cc, off, tint): cc.draw_texture_rect(tex, Rect2(local.position + off, local.size), false, tint), r.size.x * 0.04, 0.55, Vector2(r.size.x * 0.02, r.size.x * 0.03))
	c.draw_texture_rect(tex, local, false)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func background(root: Control, s: Vector2, mode: String) -> void:
	L.add_draw(root, func(c: Control) -> void:
		facets(c, s)
		L.glow(c, s * Vector2(0.6, 0.4), s.y * 0.8, Color("#48baff", 0.12), 30)
		if mode == "hero":
			L.calm_corner(c, s, Color(0.06, 0.14, 0.26, 0.6)))


func mark(kind: String) -> Dictionary:
	var spec := {
		"lines": L.words(["Godot To", "Steam"], Color.WHITE),
		"font": "Inter-ExtraBold", "track": -0.03, "line_gap": 0.18, "icon": "none",
		"layout": "h", "halign": "left", "shadow": [0.14, 0.4],
	}
	if kind in ["vertical", "library_capsule"]:
		spec.halign = "center"
		spec.text_align = "center"
	elif kind == "library_logo":
		spec.icon = "clover"
		spec.icon_scale = 1.2
		spec.gap = 0.3
		spec.halign = "center"
		spec.shadow = [0.22, 0.55]
	return spec


func capsule(root: Control, kind: String, s: Vector2) -> void:
	var clover_r: Rect2
	var text_r: Rect2
	if kind == "small":
		var side := s.y * 0.94
		clover_r = Rect2(Vector2(-side * 0.14, s.y * 0.5 - side * 0.5), Vector2(side, side))
		text_r = fr(s, 0.44, 0.1, 0.53, 0.8)
	elif tall(s):
		# Crop off the left edge only; the top lobes stay whole.
		var side := s.x * 0.78
		clover_r = Rect2(Vector2(s.x * 0.4 - side * 0.5, s.y * 0.3 - side * 0.5), Vector2(side, side))
		clover_r.position.y = maxf(clover_r.position.y, s.y * 0.02)
		text_r = fr(s, 0.08, 0.68, 0.84, 0.25)
	else:
		var side := s.y * 0.95
		clover_r = Rect2(Vector2(s.x * 0.18 - side * 0.5, s.y * 0.5 - side * 0.5), Vector2(side, side))
		text_r = fr(s, 0.53, 0.2, 0.43, 0.6)
	var spec := mark(kind)
	L.add_draw(root, func(c: Control) -> void:
		facets(c, s)
		_clover(c, clover_r, -0.18)
		L.lockup(c, text_r, spec))
