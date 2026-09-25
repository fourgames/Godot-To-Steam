extends "res://marketing/steam_art/variant_base.gd"
## 03 App Window (HAELE 3D framing): the actual app, tilted over a deep blue
## glow, with the logo on a clean dark band to its left.


func _init() -> void:
	id = "03"
	title = "App Window"
	inspired_by = "HAELE 3D"


func _bg(root: Control) -> void:
	L.add_bg(root, {
		"a": Color("#12203a"), "b": Color("#06080f"),
		"from": Vector2(0.62, 0.35), "to": Vector2(1.2, 1.1), "radial": true,
		"glows": [[Vector2(0.66, 0.4), 0.7, Color(L.ACCENT, 0.22)], [Vector2(0.2, 0.9), 0.6, Color("#1b2a4a", 0.5)]],
		"vignette": 0.2,
	})


func background(root: Control, s: Vector2, mode: String) -> void:
	L.add_bg(root, {
		"a": Color("#132444"), "b": Color("#05070d"),
		"from": Vector2(0.5, 0.5), "to": Vector2(0.5, 1.9), "radial": true,
		"glows": [[Vector2(0.5, 0.5), 0.75, Color(L.ACCENT, 0.3)]],
		"vignette": 0.1,
	})
	# Main window right of centre plus a ghost behind it; the bottom-left
	# stays dark for the library logo.
	var k := s.y * 0.8 / 900.0
	var side := L.add_draw(root, func(c: Control) -> void:
		var k2 := k * 0.8
		L.app_window(c, Vector2(s.x * 0.63 + 1440 * k * 0.5 - 1440 * k2 * 0.1, s.y * 0.08), k2, -0.05, true, {"selected": 7, "shadow": 0.4}))
	side.modulate = Color(1, 1, 1, 0.3)
	var main := L.add_draw(root, func(c: Control) -> void:
		L.app_window(c, Vector2(s.x * 0.6 - 720 * k, s.y * 0.5 - 450 * k), k, 0.0, true, {"shadow": 0.7})
		if mode == "hero":
			L.calm_corner(c, s, Color(0.02, 0.03, 0.06, 0.85)))
	if mode == "page":
		main.modulate = Color(1, 1, 1, 0.4)
		side.visible = false


func mark(kind: String) -> Dictionary:
	var spec := {
		"lines": L.words(["Godot To", "Steam"], Color.WHITE),
		"font": "Inter-ExtraBold", "track": -0.025, "icon": "tile",
		"gap": 0.3, "layout": "h",
		"halign": "left", "valign": "center", "icon_scale": 1.12,
	}
	if kind == "library_logo":
		spec.halign = "center"
		spec.valign = "center"
	return spec


## Horizontal (vertical when down) dark gradient behind the logo.
func _scrim(c: Control, s: Vector2, down: bool, reach: float, a: float) -> void:
	var dark := Color(0.02, 0.03, 0.05, a)
	var clear := Color(0.02, 0.03, 0.05, 0.0)
	if down:
		var y0 := s.y * (1.0 - reach)
		c.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(s.x, y0), Vector2(s.x, s.y), Vector2(0, s.y)]),
			PackedColorArray([clear, clear, dark, dark]))
	else:
		var x1 := s.x * reach
		c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(x1, 0), Vector2(x1, s.y), Vector2(0, s.y)]),
			PackedColorArray([dark, clear, clear, dark]))


func capsule(root: Control, kind: String, s: Vector2) -> void:
	_bg(root)
	var is_tall := tall(s)
	var k: float
	var origin: Vector2
	var rot: float
	var logo_r: Rect2
	if kind == "small":
		k = s.y * 1.25 / 900.0
		origin = Vector2(s.x * 0.52, s.y * 0.1)
		rot = -0.06
		logo_r = fr(s, 0.04, 0.08, 0.92, 0.84)
	elif is_tall:
		k = s.x * 1.05 / 1440.0
		origin = Vector2(s.x * 0.14, s.y * 0.1)
		rot = -0.075
		logo_r = fr(s, 0.06, 0.64, 0.88, 0.3)
	else:
		k = s.y * 1.12 / 900.0
		origin = Vector2(s.x * 0.56, s.y * 0.2)
		rot = -0.07
		logo_r = fr(s, 0.05, 0.2, 0.43, 0.6)
	var win := L.add_draw(root, func(c: Control) -> void:
		# Text greeked into pills: the app's look without readable copy.
		L.app_window(c, origin, k, rot, true, {"shadow": 0.6}))
	if kind == "small":
		win.visible = false
	var spec := mark(kind)
	L.add_draw(root, func(c: Control) -> void:
		if kind == "small":
			_scrim(c, s, false, 0.95, 0.9)
		elif is_tall:
			_scrim(c, s, true, 0.55, 0.96)
		else:
			_scrim(c, s, false, 0.66, 0.97)
		L.lockup(c, logo_r, spec))
