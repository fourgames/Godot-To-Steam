extends "res://marketing/steam_art/variant_base.gd"
## 04 Split Build (Lossless Scaling): one clover cut down the middle by the
## app's green progress bar. Left of it the unshipped project (dashed
## outline), right of it the shipped, glossy app icon. Godot-blue field.

const FIELD_A := Color("#2f6ab6")
const FIELD_B := Color("#1d4585")
const CELL := Color("#9be3a9")


func _init() -> void:
	id = "04"
	title = "Split Build"
	inspired_by = "Lossless Scaling"


func _field(root: Control) -> void:
	L.add_bg(root, {"a": FIELD_A, "b": FIELD_B, "from": Vector2(0.2, 0.0), "to": Vector2(0.8, 1.0), "noise": 1.4})


func _dots(c: CanvasItem, s: Vector2, x0: float, x1: float, a: float) -> void:
	var step := s.y * 0.045
	var y := step * 0.5
	while y < s.y:
		var x := x0 + step * 0.5
		while x < x1:
			c.draw_circle(Vector2(x, y), s.y * 0.0028, Color(1, 1, 1, a), true, -1.0, true)
			x += step
		y += step


## Vertical progress bar used as the cut: 20 green cells.
func _cut(c: CanvasItem, x: float, y0: float, y1: float, w: float) -> void:
	var n := 20
	var h := (y1 - y0) / n
	c.draw_rect(Rect2(x - w * 0.9, y0 - w * 0.4, w * 1.8, y1 - y0 + w * 0.8), Color(0.05, 0.15, 0.3, 0.35))
	for i in n:
		L.rrect(c, Rect2(x - w * 0.5, y0 + i * h + h * 0.08, w, h * 0.84), w * 0.18, CELL)


## Split clover in square r; the cut at r's centre x.
func split_clover(root: Control, s: Vector2, r: Rect2, line_ext: float) -> void:
	var cut := r.get_center().x
	var lw := r.size.x * 0.012
	L.add_draw(root, func(c: Control) -> void:
		# Ghost half: the project before it is exported.
		var poly := L.clover_poly_in(r)
		c.draw_colored_polygon(poly, Color(1, 1, 1, 0.24))
		var closed := poly.duplicate()
		closed.append(poly[0])
		c.draw_polyline(closed, Color(1, 1, 1, 0.75), lw * 0.8, true)
	, Rect2(Vector2(0, 0), Vector2(cut, s.y)))
	L.add_draw(root, func(c: Control) -> void:
		var tex := L.clover_tex(int(r.size.x))
		L.soft(c, func(cc, off, tint): cc.draw_texture_rect(tex, Rect2(r.position + off, r.size), false, tint), r.size.x * 0.035, 0.45, Vector2(0, r.size.x * 0.03))
		c.draw_texture_rect(tex, r, false)
	, Rect2(Vector2(cut, 0), Vector2(s.x - cut, s.y)))
	L.add_draw(root, func(c: Control) -> void:
		_cut(c, cut, r.position.y - line_ext, r.end.y + line_ext, lw * 2.4))


func mark(kind: String) -> Dictionary:
	var icon := func(c: CanvasItem, r: Rect2, tint: Color) -> void:
		var half := r.size.x * 0.5
		var tex := L.clover_tex(int(r.size.x))
		var src_r := Rect2(Vector2(tex.get_width() * 0.5, 0), Vector2(tex.get_width() * 0.5, tex.get_height()))
		if tint.a > 0.0:
			c.draw_texture_rect_region(tex, Rect2(r.position + Vector2(half, 0), Vector2(half, r.size.y)), src_r, tint)
			return
		var ghost := L.clover_tex(int(r.size.x), "#ffffff", "")
		c.draw_texture_rect_region(ghost, Rect2(r.position, Vector2(half, r.size.y)), Rect2(Vector2.ZERO, Vector2(ghost.get_width() * 0.5, ghost.get_height())), Color(1, 1, 1, 0.35))
		var otex := L.clover_tex(int(r.size.x), "none", "#ffffff", 16.0)
		c.draw_texture_rect_region(otex, Rect2(r.position, Vector2(half, r.size.y)), Rect2(Vector2.ZERO, Vector2(otex.get_width() * 0.5, otex.get_height())))
		c.draw_texture_rect_region(tex, Rect2(r.position + Vector2(half, 0), Vector2(half, r.size.y)), src_r)
		_cut(c, r.position.x + half, r.position.y - r.size.y * 0.05, r.end.y + r.size.y * 0.05, maxf(3.0, r.size.x * 0.03))
	var spec := {
		"lines": L.words(["Godot To", "Steam"], Color.WHITE),
		"font": "Inter-ExtraBold", "track": -0.025, "line_gap": 0.2, "icon": "none",
		"layout": "h", "halign": "left", "shadow": [0.12, 0.35],
	}
	if kind == "library_logo":
		spec.icon = icon
		spec.icon_scale = 1.15
		spec.gap = 0.36
		spec.halign = "center"
		spec.shadow = [0.22, 0.5]
	return spec


## Hero/page: files crossing the build line. Ghost placeholders on the
## left, solid shipped tiles with a check on the right, all inside the centre
## safe area. No clover, no text.
func background(root: Control, s: Vector2, mode: String) -> void:
	_field(root)
	var cut := s.x * 0.535
	var layer := L.add_draw(root, func(c: Control) -> void:
		_dots(c, s, 0.0, cut, 0.14)
		var sz := s.y * 0.26
		var xs := [0.355, 0.445, 0.625, 0.715]
		for i in xs.size():
			var ctr := Vector2(s.x * xs[i], s.y * (0.38 + (0.04 if i % 2 == 1 else -0.02)))
			var r := Rect2(ctr - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
			var lw := s.y * 0.007
			if ctr.x < cut:
				L.rrect(c, r, sz * 0.2, Color(1, 1, 1, 0.16), lw, Color(1, 1, 1, 0.55))
			else:
				L.rrect(c, Rect2(r.position + Vector2(0, sz * 0.06), r.size), sz * 0.2, Color(0.03, 0.1, 0.25, 0.35))
				L.rrect(c, r, sz * 0.2, Color(1, 1, 1, 0.95))
				c.draw_polyline(PackedVector2Array([ctr + Vector2(-sz * 0.2, 0), ctr + Vector2(-sz * 0.05, sz * 0.16), ctr + Vector2(sz * 0.24, -sz * 0.16)]), Color("#2d8a4e"), lw * 2.2, true)
		_cut(c, cut, s.y * 0.02, s.y * 0.98, s.y * 0.028))
	if mode == "page":
		layer.modulate = Color(1, 1, 1, 0.35)


func capsule(root: Control, kind: String, s: Vector2) -> void:
	_field(root)
	var spec := mark(kind)
	var r: Rect2
	var text_r: Rect2
	if kind == "small":
		var side := s.y * 0.92
		r = Rect2(Vector2(s.x * 0.01, s.y * 0.04), Vector2(side, side))
		text_r = Rect2(r.end.x + s.x * 0.035, s.y * 0.1, s.x * 0.96 - r.end.x - s.x * 0.035, s.y * 0.8)
	elif tall(s):
		var side := s.x * 0.6
		r = Rect2(Vector2(s.x * 0.5 - side * 0.5, s.y * 0.09), Vector2(side, side))
		text_r = fr(s, 0.08, 0.67, 0.84, 0.25)
		spec.halign = "center"
		spec.text_align = "center"
	else:
		var side := s.y * 0.76
		r = Rect2(Vector2(s.x * 0.05, s.y * 0.12), Vector2(side, side))
		text_r = Rect2(r.end.x + s.x * 0.05, s.y * 0.2, s.x * 0.95 - r.end.x - s.x * 0.05, s.y * 0.6)
	L.add_draw(root, func(c: Control) -> void: _dots(c, s, 0.0, r.get_center().x, 0.12))
	split_clover(root, s, r, r.size.y * 0.06)
	L.add_draw(root, func(c: Control) -> void: L.lockup(c, text_r, spec))
