extends "res://marketing/steam_art/variant_base.gd"
## 01 Charcoal Minimal (framepacer): the app's own charcoal, a big app icon
## and a big bold two-line wordmark. Nothing else competes.


func _init() -> void:
	id = "01"
	title = "Charcoal Minimal"
	inspired_by = "framepacer"
	page_blur = 0.0


func _flat(root: Control) -> void:
	L.add_bg(root, {"a": Color("#171717"), "b": Color("#131313"), "noise": 2.2})


func background(root: Control, s: Vector2, mode: String) -> void:
	L.add_bg(root, {
		"a": Color("#171717"), "b": Color("#111111"),
		"glows": [[Vector2(0.62, 0.42), 0.9, Color(L.ACCENT, 0.16)], [Vector2(0.62, 0.42), 0.3, Color(L.CLOVER_B, 0.08)]],
		"noise": 2.2,
	})
	# Nested app-icon tile outlines (no clover): a quiet echo of the icon.
	L.add_draw(root, func(c: Control) -> void:
		var ctr := Vector2(s.x * 0.62, s.y * 0.42)
		for i in 6:
			var side := s.y * (0.34 + i * 0.2)
			var r := Rect2(ctr - Vector2(side, side) * 0.5, Vector2(side, side))
			var a := 0.1 * (1.0 - i / 6.0)
			L.rrect(c, r, side * 0.225, Color(0, 0, 0, 0), maxf(1.0, s.y * 0.004), Color(L.CLOVER_B, a))
		var dot := s.y * 0.05
		var y := dot * 0.5
		while y < s.y:
			var x := dot * 0.5
			while x < s.x:
				var d := Vector2(x, y).distance_to(ctr) / (s.y * 1.1)
				c.draw_circle(Vector2(x, y), s.y * 0.0022, Color(1, 1, 1, 0.07 * clampf(1.0 - d, 0.0, 1.0)), true, -1.0, true)
				x += dot
			y += dot
		if mode == "hero":
			L.calm_corner(c, s, Color(0.07, 0.07, 0.07, 0.9)))


func mark(kind: String) -> Dictionary:
	var spec := {
		"lines": L.words(["Godot To", "Steam"], Color.WHITE),
		"font": "Inter-ExtraBold", "track": -0.03, "line_gap": 0.2, "icon": "tile",
		"icon_scale": 1.12, "gap": 0.3, "layout": "h",
	}
	if kind in ["vertical", "library_capsule"]:
		spec.layout = "v"
		spec.icon_scale = 1.3
		spec.gap = 0.42
	elif kind == "library_logo":
		spec.lines = L.words(["Godot To Steam"], Color.WHITE)
		spec.icon_scale = 1.9
		spec.gap = 0.4
	return spec


## Nested app-icon tile outlines centred on ctr (largest ~ max_side).
func rings(c: CanvasItem, ctr: Vector2, base: float, count: int, width: float, alpha: float) -> void:
	for i in count:
		var side := base * (1.0 + i * 0.55)
		var r := Rect2(ctr - Vector2(side, side) * 0.5, Vector2(side, side))
		var a := alpha * (1.0 - float(i) / count)
		L.rrect(c, r, side * 0.225, Color(0, 0, 0, 0), width, Color("#2f5f8a", a))


func capsule(root: Control, kind: String, s: Vector2) -> void:
	_flat(root)
	var r: Rect2
	if kind == "small":
		r = fr(s, 0.04, 0.08, 0.92, 0.84)
	elif tall(s):
		r = fr(s, 0.09, 0.2, 0.82, 0.6)
	else:
		r = fr(s, 0.07, 0.16, 0.86, 0.68)
	var spec := mark(kind)
	L.add_draw(root, func(c: Control) -> void:
		var b := L.lockup(c, r, spec.merged({"dry": true}))
		var icon_side: float
		var icon_ctr: Vector2
		if tall(s):
			# v layout: icon is ~51% of the lockup height (see mark()).
			icon_side = minf(b.size.y * 0.51, b.size.x)
			icon_ctr = Vector2(b.get_center().x, b.position.y + icon_side * 0.5)
		else:
			icon_side = b.size.y
			icon_ctr = b.position + Vector2(icon_side, icon_side) * 0.5
		L.glow(c, icon_ctr, icon_side * 1.3, Color("#1e3a5a", 0.5), 30)
		L.lockup(c, r, spec))
	if kind != "small":
		# Rings stay on the icon's side of the title (clipped), so they
		# never run behind the letters.
		var b0 := L.lockup(root, r, spec.merged({"dry": true}))
		var clip: Rect2
		var ctr: Vector2
		var side: float
		if tall(s):
			side = minf(b0.size.y * 0.51, b0.size.x)
			ctr = Vector2(b0.get_center().x, b0.position.y + side * 0.5)
			clip = Rect2(0, 0, s.x, b0.position.y + side + (b0.size.y - side) * 0.12)
		else:
			side = b0.size.y
			ctr = b0.position + Vector2(side, side) * 0.5
			clip = Rect2(0, 0, b0.position.x + side * 1.12, s.y)
		var layer := L.add_draw(root, func(c: Control) -> void:
			rings(c, ctr, side * 1.35, 1 if tall(s) else 5, maxf(1.0, s.y * 0.004), 0.7), clip)
		root.move_child(layer.get_parent() if layer.get_parent() != root else layer, 1)
