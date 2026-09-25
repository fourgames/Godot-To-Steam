extends "res://marketing/steam_art/variant_base.gd"
## Depot Waves family (variant 06, DSX-inspired): layered waves rising like an
## upload curve, the app icon and a bold wordmark. Each take in this folder
## only changes `cfg`; the drawing lives here.

## Wave layer: [base y, amplitude, frequency, phase, tilt, crest colour,
## far colour, edge line alpha]. Top layers fill up to the top edge.
const TOP_WAVES := [
	[0.2, 0.07, 0.8, 1.2, -0.5, Color("#1f3f86"), Color("#0e1a45"), 0.1],
	[0.08, 0.05, 1.1, 2.4, -0.45, Color("#2b62b8"), Color("#152a66"), 0.18],
]
const BOTTOM_WAVES := [
	[0.72, 0.06, 0.9, 0.4, -0.55, Color("#1b4f9c", 0.95), Color("#0b1740"), 0.12],
	[0.8, 0.055, 1.2, 2.0, -0.5, Color("#2f7fd0"), Color("#123a7a"), 0.22],
	[0.9, 0.05, 1.5, 3.6, -0.42, Color("#48baff"), Color("#1f6fb0"), 0.35],
	[0.98, 0.04, 1.8, 5.1, -0.3, Color("#5fd6e8"), Color("#1f7f9a"), 0.4],
]

var cfg := {
	"bg_a": Color("#0c1233"), "bg_b": Color("#070a1c"), "glow": Color("#3b5bdb", 0.18),
	"top": TOP_WAVES, "bottom": BOTTOM_WAVES,
	"style": "fill",          # fill | strands
	"mirror": false,          # waves rise to the left instead
	"layout": "center",       # center | left
	"case": "upper",          # upper | mixed
	"font": "Inter-ExtraBold",
	"icon": "tile_rim",       # tile_rim | clover
	"icon_glow": 0.0,         # halo behind the icon (alpha)
	"card": false,            # frosted glass card behind the lockup
	"crest": false,           # front wave crest drawn as progress cells
}


var _mode := "capsule"
var _kind := ""


## One wave band; returns the crest points. from_top fills to the top edge.
func _wave(c: CanvasItem, s: Vector2, w: Array, lift: float, spread: float, f: float, from_top: bool) -> PackedVector2Array:
	var base: float = w[0] - lift * (0.3 if from_top else 1.0)
	var amp: float = w[1]
	var freq: float = w[2] * f
	var phase: float = w[3]
	var tilt: float = w[4] * spread
	var top_col: Color = w[5]
	var bot_col: Color = w[6]
	var edge_a: float = w[7]
	var n := 96
	var edge := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var y := base + amp * sin(TAU * freq * t + phase) + amp * 0.35 * sin(TAU * freq * 2.3 * t + phase * 1.7) + tilt * (t - 0.5)
		if _mode == "hero" and not from_top:
			# Under the library logo (left 45%) the crests stay below 84%.
			var tx := t if not cfg.mirror else 1.0 - t
			var calm := 1.0 - smoothstep(0.35, 0.55, tx)
			y = lerpf(y, maxf(y, 0.86 + (base - 0.72) * 0.5), calm)
		edge.append(Vector2(s.x * t, s.y * y))
	if cfg.style == "strands":
		# Thin glowing lines stacked below (or above) the crest.
		var small := _kind == "small"
		var k := 7 if small else 14
		var step := s.y * (0.024 if small else 0.012)
		var lw := s.y * (0.006 if small else 0.0022)
		for j in k:
			var off := step * j * (-1.0 if from_top else 1.0)
			var line := PackedVector2Array()
			var cols := PackedColorArray()
			var glow_cols := PackedColorArray()
			var a := (1.0 - float(j) / k)
			var col := top_col.lerp(bot_col, float(j) / k)
			for p in edge:
				var q := p + Vector2(0, off)
				line.append(q)
				var fade := 1.0
				if _mode == "hero":
					var fx := q.x / s.x if not cfg.mirror else 1.0 - q.x / s.x
					fade = clampf(1.0 - (1.0 - smoothstep(0.35, 0.5, fx)) * smoothstep(0.55, 0.65, q.y / s.y), 0.0, 1.0)
				cols.append(Color(col, 0.85 * a * fade))
				glow_cols.append(Color(col, 0.08 * a * fade))
			c.draw_polyline_colors(line, glow_cols, lw * 5.0, true)
			c.draw_polyline_colors(line, cols, maxf(1.0, lw), true)
		return edge
	var far := 0.0 if from_top else s.y
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
			c.draw_polygon(PackedVector2Array([e0, e1, Vector2(e1.x, far), Vector2(e0.x, far)]), PackedColorArray([top_col, top_col, bot_col, bot_col]))
	if edge_a > 0.0:
		c.draw_polyline(edge, Color(1, 1, 1, edge_a), s.y * 0.004, true)
	return edge


func waves(c: CanvasItem, s: Vector2, spread: float, lift: float = 0.0) -> void:
	var f := clampf(s.x / s.y / 2.1, 0.5, 2.2)
	if cfg.mirror:
		c.draw_set_transform(Vector2(s.x, 0), 0.0, Vector2(-1, 1))
	for w in cfg.top:
		_wave(c, s, w, lift, spread, f, true)
	var crest := PackedVector2Array()
	var bottom: Array = cfg.bottom
	for i in bottom.size():
		var e := _wave(c, s, bottom[i], lift, spread, f, false)
		if i == bottom.size() - 1:
			crest = e
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if cfg.crest and crest.size() > 0:
		_crest_cells(c, s, crest)


## The app's progress bar riding the front crest, ending in a check.
func _crest_cells(c: CanvasItem, s: Vector2, crest: PackedVector2Array) -> void:
	if _kind == "small":
		return
	var sz := minf(s.x, s.y) * 0.026
	var start := 0.47 if _mode == "hero" else 0.04
	var stop := 0.88
	var n := int(s.x * (stop - start) / (sz * 2.0))
	var last := Vector2.ZERO
	for k in n:
		var t := start + (stop - start) * (k + 0.5) / n
		var idx := int(t * (crest.size() - 1))
		var p := crest[idx]
		if cfg.mirror:
			p.x = s.x - p.x
		p.y -= sz * 0.15
		if p.y > s.y - sz * 1.2:
			continue
		L.rrect(c, Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)).grow(maxf(1.0, s.y * 0.0015)), sz * 0.24, Color("#0b1230"))
		L.rrect(c, Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), sz * 0.2, Color("#4ade80"))
		last = p
	if last == Vector2.ZERO:
		return
	var r := sz * 1.5
	var cp := last + Vector2(sz * 2.2, -r * 0.4)
	c.draw_circle(cp, r + maxf(1.0, s.y * 0.002), Color("#0b1230"), true, -1.0, true)
	c.draw_circle(cp, r, Color("#4ade80"), true, -1.0, true)
	c.draw_polyline(PackedVector2Array([cp + Vector2(-r * 0.45, 0), cp + Vector2(-r * 0.1, r * 0.35), cp + Vector2(r * 0.48, -r * 0.35)]), Color("#0b1a12"), r * 0.22, true)


func logo(root: Control, s: Vector2) -> void:
	_mode = "logo"
	_kind = "library_logo"
	super(root, s)


func _bg(root: Control) -> void:
	L.add_bg(root, {"a": cfg.bg_a, "b": cfg.bg_b, "glows": [[Vector2(0.5, 0.45), 0.6, cfg.glow]]})


func background(root: Control, s: Vector2, mode: String) -> void:
	_mode = mode
	_kind = mode
	_bg(root)
	L.add_draw(root, func(c: Control) -> void:
		waves(c, s, 1.1, 0.12 if mode == "hero" else 0.05)
		if mode == "hero":
			L.calm_corner(c, s, Color(cfg.bg_b, 0.6)))


## App icon: tile with a lighter rim, or the bare glossy clover.
func _icon(c: CanvasItem, r: Rect2, tint: Color) -> void:
	if tint.a > 0.0:
		var t := L.icon_tile_tex(int(r.size.x)) if cfg.icon != "clover" else L.clover_tex(int(r.size.x))
		c.draw_texture_rect(t, r, false, tint)
		return
	if cfg.icon_glow > 0.0:
		var gr := r.size.x * (0.66 if _kind == "library_logo" else 1.1)
		L.glow(c, r.get_center(), gr, Color(L.CLOVER_B, cfg.icon_glow), 30)
	if cfg.icon == "clover":
		c.draw_texture_rect(L.clover_tex(int(r.size.x)), r, false)
		return
	L.rrect(c, r.grow(r.size.x * 0.018), r.size.x * 0.24, Color(cfg.bg_a.lightened(0.25)))
	c.draw_texture_rect(L.icon_tile_tex(int(r.size.x)), r, false)


func _lines(two: bool) -> Array:
	if cfg.case == "mixed":
		return L.words(["Godot To", "Steam"] if two else ["Godot To Steam"], Color.WHITE)
	return L.words(["GODOT TO", "STEAM"] if two else ["GODOT TO STEAM"], Color.WHITE)


func mark(kind: String) -> Dictionary:
	var mixed: bool = cfg.case == "mixed"
	var spec := {
		"lines": _lines(false), "font": cfg.font,
		"track": -0.025 if mixed else 0.06, "word_gap": 0.0 if mixed else 0.12,
		"icon": _icon, "icon_scale": 2.9, "gap": 0.55, "layout": "v", "line_gap": 0.22,
	}
	var two_line: bool = kind in ["small", "vertical", "library_capsule"] or cfg.layout == "left"
	if two_line:
		spec.lines = _lines(true)
	if kind == "small" or (cfg.layout == "left" and kind != "library_logo" and not kind in ["vertical", "library_capsule"]):
		spec.layout = "h"
		spec.track = -0.025 if mixed else 0.04
		spec.icon_scale = 1.12
		spec.gap = 0.3
		spec.text_align = "left"
		if cfg.layout == "left" and kind != "small":
			spec.halign = "left"
	elif kind in ["vertical", "library_capsule"]:
		spec.icon_scale = 1.45
		spec.gap = 0.45
		if cfg.layout == "left":
			spec.halign = "left"
			spec.text_align = "left"
	elif kind == "library_logo":
		spec.lines = _lines(false)
		spec.layout = "h"
		spec.icon_scale = 2.0
		spec.gap = 0.45
	if cfg.icon == "clover":
		spec.icon_scale *= 1.1
	if mixed and kind in ["header", "library_header", "main"]:
		spec.icon_scale *= 0.9
	return spec


func capsule(root: Control, kind: String, s: Vector2) -> void:
	_mode = "capsule"
	_kind = kind
	_bg(root)
	var spread := 0.9 if not tall(s) else 0.5
	L.add_draw(root, func(c: Control) -> void: waves(c, s, spread))
	var r: Rect2
	var use_card: bool = cfg.card and kind != "small"
	if kind == "small":
		r = fr(s, 0.07 if cfg.icon == "clover" else 0.045, 0.1, 0.88, 0.82)
	elif tall(s):
		r = fr(s, 0.1, 0.16, 0.8, 0.56)
	elif cfg.layout == "left":
		r = fr(s, 0.07, 0.14, 0.62, 0.6)
	elif cfg.case == "mixed":
		r = fr(s, 0.08, 0.09, 0.84, 0.62)
	else:
		r = fr(s, 0.08, 0.04, 0.84, 0.68)
	var spec := mark(kind)
	spec["shadow"] = [0.12, 0.42]
	if use_card:
		r = r.grow_individual(-s.x * 0.1, -minf(s.x, s.y) * 0.06, -s.x * 0.1, -minf(s.x, s.y) * 0.06)
	L.add_draw(root, func(c: Control) -> void:
		if use_card:
			var b := L.lockup(c, r, spec.merged({"dry": true}))
			var pad := minf(s.x, s.y) * 0.06
			var card := b.grow_individual(s.x * 0.08, pad, s.x * 0.08, pad)
			L.rrect(c, Rect2(card.position + Vector2(0, pad * 0.3), card.size), pad * 0.7, Color(0, 0, 0, 0.25))
			L.rrect(c, card, pad * 0.7, Color(0.06, 0.09, 0.2, 0.55), maxf(2.0, s.y * 0.004), Color(1, 1, 1, 0.22))
			c.draw_line(card.position + Vector2(pad * 0.7, s.y * 0.003), Vector2(card.end.x - pad * 0.7, card.position.y + s.y * 0.003), Color(1, 1, 1, 0.3), maxf(1.0, s.y * 0.003), true)
		L.lockup(c, r, spec))
