extends "res://marketing/steam_art/variant_base.gd"
## 06 Depot Waves (DSX): layered waves rise like an upload curve from the
## bottom-left (clover cyan into success green); deep blue pours in from the
## top-right. Centred app icon, widely spaced caps.


func _init() -> void:
	id = "06"
	title = "Depot Waves"
	inspired_by = "DSX"


## One wave band. from_top: fill to the top edge instead of the bottom.
func _wave(c: CanvasItem, s: Vector2, base: float, amp: float, freq: float, phase: float, tilt: float, top_col: Color, bot_col: Color, from_top: bool, edge_a: float) -> void:
	var n := 96
	var edge := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var y := base + amp * sin(TAU * freq * t + phase) + amp * 0.35 * sin(TAU * freq * 2.3 * t + phase * 1.7) + tilt * (t - 0.5)
		edge.append(Vector2(s.x * t, s.y * y))
	var far := 0.0 if from_top else s.y
	# Quads from the edge to the far side; clamp and skip slivers so the
	# triangulation never sees a degenerate polygon.
	for i in n:
		var e0 := Vector2(edge[i].x, clampf(edge[i].y, 0.0, s.y))
		var e1 := Vector2(edge[i + 1].x, clampf(edge[i + 1].y, 0.0, s.y))
		var flat0 := absf(e0.y - far) < 0.5
		var flat1 := absf(e1.y - far) < 0.5
		if flat0 and flat1:
			continue
		if flat0:
			c.draw_polygon(PackedVector2Array([e0, e1, Vector2(e1.x, far)]), PackedColorArray([bot_col, top_col, bot_col]))
		elif flat1:
			c.draw_polygon(PackedVector2Array([e0, e1, Vector2(e0.x, far)]), PackedColorArray([top_col, bot_col, bot_col]))
		else:
			var q := PackedVector2Array([e0, e1, Vector2(e1.x, far), Vector2(e0.x, far)])
			c.draw_polygon(q, PackedColorArray([top_col, top_col, bot_col, bot_col]))
	c.draw_polyline(edge, Color(1, 1, 1, edge_a), s.y * 0.004, true)


func waves(c: CanvasItem, s: Vector2, spread: float, lift: float = 0.0) -> void:
	var aspect := s.x / s.y
	var f := clampf(aspect / 2.1, 0.5, 2.2)
	# Top-right: deep blue pouring down.
	_wave(c, s, 0.2 - lift * 0.3, 0.07, 0.8 * f, 1.2, -0.5 * spread, Color("#1f3f86"), Color("#0e1a45"), true, 0.1)
	_wave(c, s, 0.08 - lift * 0.3, 0.05, 1.1 * f, 2.4, -0.45 * spread, Color("#2b62b8"), Color("#152a66"), true, 0.18)
	# Bottom-left: the upload curve, rising to the right.
	_wave(c, s, 0.72 - lift, 0.06, 0.9 * f, 0.4, -0.55 * spread, Color("#1b4f9c", 0.95), Color("#0b1740"), false, 0.12)
	_wave(c, s, 0.8 - lift, 0.055, 1.2 * f, 2.0, -0.5 * spread, Color("#2f7fd0"), Color("#123a7a"), false, 0.22)
	_wave(c, s, 0.9 - lift * 0.8, 0.05, 1.5 * f, 3.6, -0.42 * spread, Color("#48baff"), Color("#1f6fb0"), false, 0.35)
	_wave(c, s, 0.98 - lift * 0.6, 0.04, 1.8 * f, 5.1, -0.3 * spread, Color("#5fd6e8"), Color("#1f7f9a"), false, 0.4)


func _bg(root: Control) -> void:
	L.add_bg(root, {
		"a": Color("#0c1233"), "b": Color("#070a1c"),
		"glows": [[Vector2(0.5, 0.45), 0.6, Color("#3b5bdb", 0.18)]],
	})


func background(root: Control, s: Vector2, mode: String) -> void:
	_bg(root)
	L.add_draw(root, func(c: Control) -> void:
		waves(c, s, 1.1, 0.12 if mode == "hero" else 0.05)
		if mode == "hero":
			L.calm_corner(c, s, Color(0.03, 0.04, 0.12, 0.55)))


## App icon tile with a thin lighter rim so it lifts off the navy.
func _tile(c: CanvasItem, r: Rect2, tint: Color) -> void:
	if tint.a > 0.0:
		c.draw_texture_rect(L.icon_tile_tex(int(r.size.x)), r, false, tint)
		return
	L.rrect(c, r.grow(r.size.x * 0.018), r.size.x * 0.24, Color("#2a4a9a"))
	c.draw_texture_rect(L.icon_tile_tex(int(r.size.x)), r, false)


func mark(kind: String) -> Dictionary:
	var spec := {
		"lines": L.words(["GODOT TO STEAM"], Color.WHITE),
		"font": "Inter-ExtraBold", "track": 0.06, "word_gap": 0.12, "icon": _tile,
		"icon_scale": 2.9, "gap": 0.55, "layout": "v",
	}
	if kind == "small":
		spec.lines = L.words(["GODOT TO", "STEAM"], Color.WHITE)
		spec.layout = "h"
		spec.track = 0.04
		spec.icon_scale = 1.12
		spec.gap = 0.3
		spec.line_gap = 0.26
		spec.text_align = "left"
	elif kind in ["vertical", "library_capsule"]:
		spec.lines = L.words(["GODOT TO", "STEAM"], Color.WHITE)
		spec.icon_scale = 1.45
		spec.gap = 0.45
		spec.line_gap = 0.26
	elif kind == "library_logo":
		spec.layout = "h"
		spec.icon_scale = 2.0
		spec.gap = 0.45
	return spec


func capsule(root: Control, kind: String, s: Vector2) -> void:
	_bg(root)
	var spread := 0.9 if not tall(s) else 0.5
	L.add_draw(root, func(c: Control) -> void: waves(c, s, spread))
	var r: Rect2
	if kind == "small":
		r = fr(s, 0.045, 0.08, 0.91, 0.84)
	elif tall(s):
		r = fr(s, 0.1, 0.16, 0.8, 0.56)
	else:
		r = fr(s, 0.08, 0.06, 0.84, 0.7)
	var spec := mark(kind)
	spec["shadow"] = [0.25, 0.45]
	L.add_draw(root, func(c: Control) -> void: L.lockup(c, r, spec))
