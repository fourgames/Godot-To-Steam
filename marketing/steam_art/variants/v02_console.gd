extends "res://marketing/steam_art/variant_base.gd"
## 02 Console Night (SaveSync + the app's console): the app's build log
## (greeked: shapes of text, no readable copy) fills the frame; a mono
## wordmark with a green cursor sits on a dark band, underlined by the app's
## 100% progress bar.


func _init() -> void:
	id = "02"
	title = "Console Night"
	inspired_by = "SaveSync + the app console"


func background(root: Control, s: Vector2, mode: String) -> void:
	L.add_bg(root, {
		"a": Color("#121614"), "b": Color("#0b0d0c"),
		"glows": [[Vector2(0.5, 0.5), 0.8, Color(L.ACCENT, 0.05)]],
		"vignette": 0.3,
	})
	L.add_draw(root, func(c: Control) -> void:
		var fs := s.y * (0.03 if mode == "capsule" else 0.021)
		if mode == "capsule" and tall(s):
			fs = s.x * 0.03
		var lines := L.console_lines()
		if mode == "hero":
			# Three console columns, busiest on the right; the left column
			# stays quiet under the library logo.
			# Columns start right of the library logo's zone (x > 42%); the
			# left one only fills the top half.
			var xs := [0.0, 0.43, 0.72, 1.0]
			for col in 3:
				var a: float = [0.14, 0.5, 0.3][col]
				var h := s.y * (0.46 if col == 0 else 0.98)
				var x0: float = s.x * xs[col] + s.y * 0.06
				L.console(c, Rect2(x0, s.y * 0.01, s.x * (xs[col + 1] - xs[col]) - s.y * 0.12, h), lines, fs, a, true, col * 7)
			for col in range(1, 3):
				c.draw_line(Vector2(s.x * xs[col], 0), Vector2(s.x * xs[col], s.y), Color(1, 1, 1, 0.05), s.y * 0.002)
			L.calm_corner(c, s, Color(0.043, 0.051, 0.047, 0.92))
		else:
			L.console(c, Rect2(s.x * 0.04, -fs * 0.4, s.x * 1.2, s.y * 1.1), lines, fs, 0.26 if mode == "capsule" else 0.22, true, 3))


func mark(kind: String) -> Dictionary:
	var spec := {
		"lines": L.words(["Godot To", "Steam"], Color.WHITE),
		"font": "IBMPlexMono-Bold", "track": -0.04, "word_gap": -0.22, "cap": 0.698,
		"icon": "tile", "icon_scale": 1.15, "gap": 0.3, "layout": "h", "line_gap": 0.22,
		"cursor": L.GREEN,
	}
	if kind == "library_logo":
		spec.lines = L.words(["Godot To Steam"], Color.WHITE)
		spec.icon_scale = 1.9
		spec.gap = 0.4
	elif kind in ["vertical", "library_capsule"]:
		spec.layout = "v"
		spec.icon_scale = 1.35
		spec.gap = 0.45
	return spec


func capsule(root: Control, kind: String, s: Vector2) -> void:
	background(root, s, "capsule")
	var r: Rect2
	var bar_h: float
	if kind == "small":
		r = fr(s, 0.05, 0.07, 0.9, 0.7)
		bar_h = s.y * 0.07
	elif tall(s):
		r = fr(s, 0.08, 0.24, 0.84, 0.44)
		bar_h = s.y * 0.03
	else:
		r = fr(s, 0.08, 0.12, 0.84, 0.62)
		bar_h = s.y * 0.05
	var spec := mark(kind)
	L.add_draw(root, func(c: Control) -> void:
		var b := L.lockup(c, r, spec.merged({"dry": true}))
		var br := Rect2(b.position.x, b.end.y + bar_h * (1.2 if kind != "small" else 0.7), b.size.x, bar_h)
		# Solid dark band behind title + bar, feathered top and bottom.
		var band := Rect2(0, b.position.y - s.y * 0.06, s.x, br.end.y - b.position.y + s.y * 0.12)
		if kind == "small":
			band = Rect2(Vector2.ZERO, s)
		var dark := Color("#0e1110", 0.94)
		var clear := Color(dark, 0.0)
		var f := s.y * 0.07
		c.draw_rect(band, dark)
		c.draw_polygon(PackedVector2Array([Vector2(0, band.position.y - f), Vector2(s.x, band.position.y - f), Vector2(s.x, band.position.y), Vector2(0, band.position.y)]), PackedColorArray([clear, clear, dark, dark]))
		c.draw_polygon(PackedVector2Array([Vector2(0, band.end.y), Vector2(s.x, band.end.y), Vector2(s.x, band.end.y + f), Vector2(0, band.end.y + f)]), PackedColorArray([dark, dark, clear, clear]))
		L.lockup(c, r, spec)
		c.draw_set_transform(br.get_center(), 0.0, Vector2(1.0, 0.14))
		L.glow(c, Vector2.ZERO, br.size.x * 0.55, Color(L.GREEN, 0.2), 24)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 100% bar ending in a green check: the upload is live.
		var ck := bar_h * 1.05
		var bar := Rect2(br.position, Vector2(br.size.x - ck * 2.6, br.size.y))
		L.progress_cells(c, bar, 1.0, L.GREEN, L.GUTTER, 20, 0.08, bar_h * 0.1)
		var cc := Vector2(br.end.x - ck, br.get_center().y)
		c.draw_circle(cc, ck, L.GREEN, true, -1.0, true)
		c.draw_polyline(PackedVector2Array([cc + Vector2(-ck * 0.45, 0), cc + Vector2(-ck * 0.1, ck * 0.35), cc + Vector2(ck * 0.48, -ck * 0.35)]), Color("#0e1110"), ck * 0.22, true))
