extends "res://marketing/steam_art/variant_base.gd"
## 05 Clover Ripple (Mouse X): neon clover outlines radiate from the icon over
## charcoal-to-navy; the wordmark sits in a thin outlined box.

const NEON := Color("#48baff")


func _init() -> void:
	id = "05"
	title = "Clover Ripple"
	inspired_by = "Mouse X"


func _bg(root: Control, center_uv: Vector2) -> void:
	L.add_bg(root, {
		"a": Color("#16264a"), "b": Color("#0b0d14"),
		"from": center_uv, "to": center_uv + Vector2(0, 1.3), "radial": true,
		"glows": [[center_uv, 0.45, Color(NEON, 0.12)]],
	})


## Ripple rings of the clover outline around center; base = inner clover size.
func ripples(c: CanvasItem, center: Vector2, base: float, count: int, width: float, alpha: float = 1.0, first: int = 1, rot: float = 0.0, twist: float = 0.0) -> void:
	var poly := L.clover_poly()
	var box := L.clover_box()
	for i in range(count, first - 1, -1):
		var scale := base * pow(1.42, i) / box.size.x
		var pts := PackedVector2Array()
		for p in poly:
			pts.append(center + ((p - box.get_center()) * scale).rotated(rot + twist * i))
		pts.append(pts[0])
		var t := float(i) / count
		var a := lerpf(0.75, 0.1, t) * alpha
		var col := NEON.lerp(Color("#3b5bdb"), t)
		c.draw_polyline(pts, Color(col, a * 0.1), width * 7.0, true)
		c.draw_polyline(pts, Color(col, a * 0.22), width * 3.0, true)
		c.draw_polyline(pts, Color(col, a), width, true)


func _icon(c: CanvasItem, r: Rect2, rot: float = -0.14) -> void:
	L.glow(c, r.get_center(), r.size.x * 0.85, Color(NEON, 0.3), 28)
	var tex := L.clover_tex(int(r.size.x))
	var local := Rect2(-r.size * 0.5, r.size)
	c.draw_set_transform(r.get_center(), rot, Vector2.ONE)
	L.soft(c, func(cc, off, tint): cc.draw_texture_rect(tex, Rect2(local.position + off, local.size), false, tint), r.size.x * 0.04, 0.5, Vector2(0, r.size.x * 0.03))
	c.draw_texture_rect(tex, local, false)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func mark(kind: String) -> Dictionary:
	var spec := {
		"lines": L.words(["Godot To Steam"], Color.WHITE, {"Steam": Color("#8fd8ff")}),
		"font": "Inter-ExtraBold", "track": -0.02, "icon": "none", "layout": "h",
	}
	if kind in ["small", "vertical", "library_capsule"]:
		spec.lines = L.words(["Godot To", "Steam"], Color.WHITE, {"Steam": Color("#8fd8ff")})
	if kind == "library_logo":
		spec.icon = "clover"
		spec.icon_scale = 1.9
		spec.gap = 0.4
	return spec


## The wordmark inside a thin outlined box, like Mouse X's name plate.
func _plate(c: CanvasItem, r: Rect2, spec: Dictionary) -> void:
	var pad := Vector2(r.size.y * 0.16, r.size.y * 0.16)
	var inner := Rect2(r.position + pad, r.size - pad * 2.0)
	var dry := spec.duplicate()
	dry["dry"] = true
	var probe := L.lockup(c, Rect2(Vector2.ZERO, inner.size), dry)
	var box := Rect2(r.position + (r.size - probe.size - pad * 2.0) * Vector2(0.0 if spec.get("halign", "center") == "left" else 0.5, 0.5), probe.size + pad * 2.0)
	L.rrect(c, box, pad.y * 0.35, Color("#1a2a6c", 0.72), maxf(2.0, r.size.y * 0.014), Color("#4f74ff"), pad.y * 1.4, Color(0, 0, 0, 0.35), Vector2(0, pad.y * 0.4))
	L.lockup(c, Rect2(box.position + pad, probe.size), spec)


func background(root: Control, s: Vector2, mode: String) -> void:
	var ctr := Vector2(0.62, 0.45)
	_bg(root, ctr)
	L.add_draw(root, func(c: Control) -> void:
		# Rings only (no clover at the centre, which would be the logo): a
		# bright core where the icon would sit.
		var base := s.y * 0.2
		# Each ring turns a little further, so the field reads as a vortex
		# pattern rather than a repeat of the clover mark.
		ripples(c, s * ctr, base, 9, s.y * 0.0045, 0.6 if mode == "hero" else 0.4, 2, -0.14, 0.2)
		L.glow(c, s * ctr, s.y * 0.35, Color(NEON, 0.35 if mode == "hero" else 0.14), 36)
		if mode == "hero":
			L.calm_corner(c, s, Color(0.04, 0.05, 0.08, 0.85)))


func capsule(root: Control, kind: String, s: Vector2) -> void:
	var spec := mark(kind)
	var icon_r: Rect2
	var plate_r: Rect2
	if kind == "small":
		var side := s.y * 0.98
		icon_r = Rect2(Vector2(s.x * 1.0 - side * 0.8, s.y * 0.5 - side * 0.5), Vector2(side, side))
		plate_r = Rect2(s.x * 0.03, s.y * 0.08, icon_r.position.x - s.x * 0.03 - s.y * 0.1, s.y * 0.84)
		spec.halign = "left"
	elif tall(s):
		var side := s.x * 0.66
		icon_r = Rect2(Vector2(s.x * 0.53 - side * 0.5, s.y * 0.07), Vector2(side, side))
		plate_r = fr(s, 0.05, 0.65, 0.9, 0.29)
	else:
		var side := s.y * 0.78
		icon_r = Rect2(Vector2(s.x * 0.95 - side, s.y * 0.5 - side * 0.5), Vector2(side, side))
		plate_r = Rect2(s.x * 0.03, s.y * 0.22, icon_r.position.x - s.x * 0.03 - s.y * 0.06, s.y * 0.56)
		spec.halign = "left"
	_bg(root, icon_r.get_center() / s)
	L.add_draw(root, func(c: Control) -> void:
		ripples(c, icon_r.get_center(), icon_r.size.x, 7, s.y * (0.004 if kind != "small" else 0.006), 1.0, 1, -0.14)
		_plate(c, plate_r, spec)
		_icon(c, icon_r))
