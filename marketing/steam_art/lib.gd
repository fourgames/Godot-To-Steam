extends RefCounted
## Shared drawing helpers for the Steam art studio.
##
## Everything is drawn in absolute pixels of the (supersampled) render target,
## so callers size things relative to the canvas they are given. Nothing here
## uses class_name: the art studio is excluded from export and must not leak
## into the global class cache (see export_presets.cfg).

const DrawLayer := preload("res://marketing/steam_art/draw_layer.gd")
const BG_SHADER := preload("res://marketing/steam_art/bg.gdshader")

# Palette: tools/theme_generator.py and main_window.gd console colours.
const APP_BG := Color("#151515")
const SIDEBAR := Color("#111111")
const CARD := Color("#212121")
const CARD_HOVER := Color("#282828")
const INPUT := Color("#1a1a1a")
const CONSOLE := Color("#1a1a19")
const COMPOSER := Color("#20201f")
const BORDER := Color("#262626")
const BORDER_STRONG := Color("#333333")
const TEXT := Color("#ececec")
const TEXT_2 := Color("#a3a3a3")
const MUTED := Color("#8a8a8a")
const ACCENT := Color("#478cbf")
const ACCENT_HI := Color("#5a9cd0")
const CMD := Color("#7fb6e0")
const GREEN := Color("#86c29a")
const WARN := Color("#d9a64a")
const ERR := Color("#e07b72")
const STAMP := Color("#808080")
const GUTTER := Color("#333333")
const CLOVER_A := Color("#4a90e2")
const CLOVER_B := Color("#48baff")
const TILE_A := Color("#1b2a4a")
const TILE_B := Color("#070b16")

## Cap height of Inter / Inter Tight as a fraction of the font size.
const CAP := 0.727

const ICON_SVG := "res://public/app_icon_macos.svg"

static var _fonts: Dictionary = {}
static var _tex: Dictionary = {}
static var _clover_d := ""
static var _clover_poly := PackedVector2Array()
static var _clover_bbox := Rect2()


# --- Fonts -------------------------------------------------------------------

## Loads an exact font file from /Library/Fonts or ~/Library/Fonts (e.g. "Inter-ExtraBold").
## SystemFont is ambiguous here because Inter, Inter 18pt and Inter Tight are
## all installed side by side.
static func font(file: String) -> Font:
	if _fonts.has(file):
		return _fonts[file]
	var f := FontFile.new()
	var path := "/Library/Fonts/" + file + ".ttf"
	if not FileAccess.file_exists(path):
		path = OS.get_environment("HOME") + "/Library/Fonts/" + file + ".ttf"
	var err := f.load_dynamic_font(path)
	if err != OK:
		push_error("Steam art: missing font " + path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(["Menlo", "Apple Symbols", "Arial Unicode MS"])
	fallback.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.fallbacks = [fallback]
	_fonts[file] = f
	return f


## Same font with letter spacing in pixels (tracking scales with size, so the
## caller converts em to px for the size it draws at).
static func tracked(file: String, spacing_px: int) -> Font:
	if spacing_px == 0:
		return font(file)
	var key := "%s@%d" % [file, spacing_px]
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	fv.base_font = font(file)
	fv.spacing_glyph = spacing_px
	_fonts[key] = fv
	return fv


static func text_w(f: Font, t: String, fs: int) -> float:
	return f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## Draws text with its baseline-left at pos.
static func text(c: CanvasItem, f: Font, t: String, pos: Vector2, fs: int, col: Color) -> void:
	c.draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Draws text so its cap-height box is vertically centred on y.
static func text_mid(c: CanvasItem, f: Font, t: String, x: float, y: float, fs: int, col: Color) -> void:
	c.draw_string(f, Vector2(x, y + fs * CAP * 0.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# --- Textures ----------------------------------------------------------------

static func svg_tex(svg: String, px_w: int, svg_w: float) -> Texture2D:
	var key := "%d:%d" % [svg.hash(), px_w]
	if _tex.has(key):
		return _tex[key]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, float(px_w) / svg_w)
	if err != OK:
		push_error("Steam art: SVG failed to load")
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


static func svg_file_tex(path: String, px_w: int) -> Texture2D:
	var svg := FileAccess.get_file_as_string(path)
	var w := 32.0
	var re := RegEx.new()
	re.compile("width=\"([0-9.]+)\"")
	var m := re.search(svg)
	if m:
		w = float(m.get_string(1))
	return svg_tex(svg, px_w, w)


## The app icon tile (squircle + clover), cropped to the tile edges.
static func icon_tile_tex(px: int) -> Texture2D:
	var svg := FileAccess.get_file_as_string(ICON_SVG)
	svg = svg.replace("width=\"1024\" height=\"1024\" viewBox=\"0 0 1024 1024\"",
		"width=\"824\" height=\"824\" viewBox=\"100 100 824 824\"")
	return svg_tex(svg, px, 824.0)


static func platform_tex(name: String, px: int) -> Texture2D:
	return svg_file_tex("res://public/icons/platforms/%s.svg" % name, px)


static func editor_icon_tex(name: String, px: int) -> Texture2D:
	return svg_file_tex("res://public/icons/editor/%s.svg" % name, px)


# --- Clover ------------------------------------------------------------------

static func clover_d() -> String:
	if _clover_d == "":
		var svg := FileAccess.get_file_as_string(ICON_SVG)
		var re := RegEx.new()
		re.compile("<path d=\"([^\"]+)\"")
		_clover_d = re.search(svg).get_string(1)
	return _clover_d


## Clover outline as a polygon in the path's own units (about 0..512).
static func clover_poly() -> PackedVector2Array:
	if not _clover_poly.is_empty():
		return _clover_poly
	var re := RegEx.new()
	re.compile("[MmCcLlZz]|-?(?:\\d+\\.?\\d*|\\.\\d+)")
	var toks: PackedStringArray = []
	for m in re.search_all(clover_d()):
		toks.append(m.get_string())
	var pts := PackedVector2Array()
	var cur := Vector2.ZERO
	var start := Vector2.ZERO
	var cmd := ""
	var i := 0
	while i < toks.size():
		var t := toks[i]
		if "MmCcLlZz".contains(t):
			cmd = t
			i += 1
			if cmd == "z" or cmd == "Z":
				cur = start
			continue
		if cmd == "M" or cmd == "m":
			var p := Vector2(float(toks[i]), float(toks[i + 1]))
			cur = p if cmd == "M" else cur + p
			start = cur
			pts.append(cur)
			cmd = "L" if cmd == "M" else "l"
			i += 2
		elif cmd == "L" or cmd == "l":
			var p := Vector2(float(toks[i]), float(toks[i + 1]))
			cur = p if cmd == "L" else cur + p
			pts.append(cur)
			i += 2
		elif cmd == "C" or cmd == "c":
			var p1 := Vector2(float(toks[i]), float(toks[i + 1]))
			var p2 := Vector2(float(toks[i + 2]), float(toks[i + 3]))
			var p3 := Vector2(float(toks[i + 4]), float(toks[i + 5]))
			if cmd == "c":
				p1 += cur
				p2 += cur
				p3 += cur
			for k in range(1, 17):
				var tt := k / 16.0
				var u := 1.0 - tt
				pts.append(cur * u * u * u + p1 * 3.0 * u * u * tt + p2 * 3.0 * u * tt * tt + p3 * tt * tt * tt)
			cur = p3
			i += 6
		else:
			i += 1
	# Drop the duplicated closing point.
	if pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) < 0.01:
		pts.remove_at(pts.size() - 1)
	_clover_poly = pts
	var mn := pts[0]
	var mx := pts[0]
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	_clover_bbox = Rect2(mn, mx - mn)
	return _clover_poly


## Path-space box the clover is drawn in: its bbox squared up plus room for a
## stroke. Textures and polygons both map this box onto the target rect, so a
## vector outline lines up exactly with the rasterised clover.
static func clover_box() -> Rect2:
	clover_poly()
	var side := maxf(_clover_bbox.size.x, _clover_bbox.size.y) + 28.0
	var c := _clover_bbox.get_center()
	return Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side))


## Clover polygon mapped into rect (a square rect keeps the proportions).
static func clover_poly_in(rect: Rect2) -> PackedVector2Array:
	var box := clover_box()
	var out := PackedVector2Array()
	for p in clover_poly():
		out.append(rect.position + (p - box.position) / box.size * rect.size)
	return out


## fill: "grad" (the app's radial blue), a colour string, or "none".
static func clover_svg(fill: String, stroke: String = "", stroke_w: float = 0.0) -> String:
	var box := clover_box()
	var defs := "<defs><radialGradient id=\"g\"><stop offset=\"0%\" stop-color=\"#4a90e2\"/><stop offset=\"100%\" stop-color=\"#48baff\"/></radialGradient></defs>"
	var f := "url(#g)" if fill == "grad" else fill
	var st := ""
	if stroke != "":
		st = " stroke=\"%s\" stroke-width=\"%.2f\" stroke-linejoin=\"round\"" % [stroke, stroke_w]
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%.3f\" height=\"%.3f\" viewBox=\"%.3f %.3f %.3f %.3f\">%s<path d=\"%s\" fill=\"%s\"%s/></svg>" % [
		box.size.x, box.size.y, box.position.x, box.position.y, box.size.x, box.size.y,
		defs, clover_d(), f, st]


static func clover_tex(px: int, fill: String = "grad", stroke: String = "#ffffff", stroke_w: float = 20.0) -> Texture2D:
	return svg_tex(clover_svg(fill, stroke, stroke_w), px, clover_box().size.x)


# --- Layers ------------------------------------------------------------------

## Full-rect background drawn by bg.gdshader (dithered gradient + glows).
## p: a, b (Color), from, to (Vector2 uv), glows: Array of [Vector2 uv, radius
## as fraction of height, Color], vignette (float), noise (float, /255).
static func add_bg(root: Control, p: Dictionary, rect: Rect2 = Rect2()) -> ColorRect:
	var cr := ColorRect.new()
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rect.size == Vector2.ZERO:
		rect = Rect2(Vector2.ZERO, root.size)
	cr.position = rect.position
	cr.size = rect.size
	var mat := ShaderMaterial.new()
	mat.shader = BG_SHADER
	mat.set_shader_parameter("rect_size", rect.size)
	mat.set_shader_parameter("col_a", p.get("a", APP_BG))
	mat.set_shader_parameter("col_b", p.get("b", p.get("a", APP_BG)))
	mat.set_shader_parameter("grad_from", p.get("from", Vector2(0, 0)))
	mat.set_shader_parameter("grad_to", p.get("to", Vector2(0, 1)))
	mat.set_shader_parameter("radial", 1.0 if p.get("radial", false) else 0.0)
	var glows: Array = p.get("glows", [])
	var gpos := PackedVector3Array()
	var gcol := PackedColorArray()
	for g in glows:
		gpos.append(Vector3(g[0].x, g[0].y, g[1]))
		gcol.append(g[2])
	while gpos.size() < 6:
		gpos.append(Vector3.ZERO)
		gcol.append(Color(0, 0, 0, 0))
	mat.set_shader_parameter("glow", gpos)
	mat.set_shader_parameter("glow_color", gcol)
	mat.set_shader_parameter("glow_count", glows.size())
	mat.set_shader_parameter("vignette", p.get("vignette", 0.0))
	mat.set_shader_parameter("noise", p.get("noise", 1.5))
	cr.material = mat
	root.add_child(cr)
	return cr


## A layer whose _draw calls fn(layer). clip_rect > 0 clips to that rect; the
## callable still draws in root coordinates.
static func add_draw(root: Control, fn: Callable, clip_rect: Rect2 = Rect2()) -> Control:
	var holder: Control = root
	var offset := Vector2.ZERO
	if clip_rect.size != Vector2.ZERO:
		holder = Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.clip_contents = true
		holder.position = clip_rect.position
		holder.size = clip_rect.size
		root.add_child(holder)
		offset = -clip_rect.position
	var layer := DrawLayer.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.position = offset
	layer.size = root.size
	layer.fn = fn
	holder.add_child(layer)
	return layer


# --- Shapes ------------------------------------------------------------------

static func rrect(c: CanvasItem, r: Rect2, radius: float, col: Color, border: float = 0.0, border_col: Color = Color.TRANSPARENT, shadow: float = 0.0, shadow_col: Color = Color(0, 0, 0, 0.45), shadow_off: Vector2 = Vector2.ZERO) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(round(radius)))
	sb.corner_detail = 16
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.2
	if border > 0.0:
		sb.set_border_width_all(int(maxf(1.0, round(border))))
		sb.border_color = border_col
	if shadow > 0.0:
		sb.shadow_size = int(shadow)
		sb.shadow_color = shadow_col
		sb.shadow_offset = shadow_off
	c.draw_style_box(sb, r)


## Soft blurred shadow of any draw callable (fn(c, offset, tint)) by stacking
## offset copies. Cheap stand-in for a Gaussian drop shadow.
static func soft(c: CanvasItem, fn: Callable, radius: float, alpha: float, offset: Vector2 = Vector2.ZERO) -> void:
	var taps: Array[Vector2] = [Vector2.ZERO]
	for ring in [0.17, 0.33, 0.5, 0.67, 0.83, 1.0]:
		var n := 16
		for k in n:
			var a := TAU * k / n + float(ring)
			taps.append(Vector2(cos(a), sin(a)) * radius * float(ring))
	var per := 1.0 - pow(1.0 - alpha, 1.0 / taps.size())
	for t in taps:
		fn.call(c, offset + t, Color(0, 0, 0, per))


## Radial glow made of stacked translucent circles.
static func glow(c: CanvasItem, center: Vector2, radius: float, col: Color, steps: int = 24) -> void:
	for k in steps:
		var t := 1.0 - float(k) / steps
		c.draw_circle(center, radius * t, Color(col.r, col.g, col.b, col.a / steps * (1.0 - t * 0.2)), true, -1.0, true)


static func dashed_line(c: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float, dash: float, gap: float) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var d := 0.0
	while d < length:
		c.draw_line(a + dir * d, a + dir * minf(d + dash, length), col, width, true)
		d += dash + gap


## The app's console progress bar: 20 cells, filled cells in col.
static func progress_cells(c: CanvasItem, r: Rect2, pct: float, col: Color, empty: Color = GUTTER, cells: int = 20, gap_frac: float = 0.0, radius: float = 0.0) -> void:
	var w := r.size.x / cells
	var filled := int(round(pct * cells))
	for k in cells:
		var cr := Rect2(r.position.x + k * w, r.position.y, w - w * gap_frac, r.size.y)
		var cc := col if k < filled else empty
		if radius > 0.0:
			rrect(c, cr, radius, cc)
		else:
			c.draw_rect(cr, cc)


# --- Wordmark / lockup -------------------------------------------------------

## Builds line segments: words(["Godot To", "Steam"], white, {"To": blue}).
static func words(lines: Array, col: Color, accents: Dictionary = {}) -> Array:
	var out: Array = []
	for line in lines:
		var segs: Array = []
		for w in String(line).split(" "):
			segs.append([w, accents.get(w, col)])
		out.append(segs)
	return out


## Lockup spec keys:
##   lines: from words(); font: font file; track: em; line_gap: em between cap
##   lines; icon: "tile" | "clover" | "white" | "outline" | "badge" | "pixel" |
##   "none" | Callable(c, rect); icon_scale: icon size / text block height;
##   layout: "h" | "v"; gap: em between icon and text; halign/valign:
##   "left" | "center" | "right" / "top" | "center" | "bottom"; text_align:
##   "left" | "center"; shadow: [radius_em, alpha]; case: "upper" | "".
## Returns the drawn bounds.
static func lockup(c: CanvasItem, rect: Rect2, spec: Dictionary) -> Rect2:
	var lines: Array = spec.get("lines", words(["Godot To Steam"], TEXT))
	var file: String = spec.get("font", "Inter-ExtraBold")
	var track: float = spec.get("track", -0.02)
	var line_gap: float = spec.get("line_gap", 0.26)
	var icon = spec.get("icon", "tile")
	var icon_scale: float = spec.get("icon_scale", 1.0)
	var layout: String = spec.get("layout", "h")
	var gap: float = spec.get("gap", 0.34)
	var cap: float = spec.get("cap", CAP)
	var has_icon: bool = not (icon is String and icon == "none")
	var cursor: Color = spec.get("cursor", Color(0, 0, 0, 0))
	var word_gap: float = spec.get("word_gap", 0.0)
	var fs := 100
	var m := _measure(lines, file, track, fs, cursor.a > 0.0, word_gap)
	var block_w: float = m[0]
	var block_h: float = lines.size() * cap * fs + (lines.size() - 1) * line_gap * fs
	var icon_px := block_h * icon_scale if has_icon else 0.0
	var gap_px := gap * fs if has_icon else 0.0
	var tw: float
	var th: float
	if layout == "h":
		tw = icon_px + gap_px + block_w
		th = maxf(icon_px, block_h)
	else:
		tw = maxf(icon_px, block_w)
		th = icon_px + gap_px + block_h
	var k := minf(rect.size.x / tw, rect.size.y / th)
	fs = int(floor(fs * k))
	# Re-measure at the real size (tracking is integer pixels).
	m = _measure(lines, file, track, fs, cursor.a > 0.0, word_gap)
	block_w = m[0]
	block_h = lines.size() * cap * fs + (lines.size() - 1) * line_gap * fs
	icon_px = block_h * icon_scale if has_icon else 0.0
	gap_px = gap * fs if has_icon else 0.0
	if layout == "h":
		tw = icon_px + gap_px + block_w
		th = maxf(icon_px, block_h)
	else:
		tw = maxf(icon_px, block_w)
		th = icon_px + gap_px + block_h
	var ha: String = spec.get("halign", "center")
	var va: String = spec.get("valign", "center")
	var ox := rect.position.x + (rect.size.x - tw) * (0.0 if ha == "left" else (1.0 if ha == "right" else 0.5))
	var oy := rect.position.y + (rect.size.y - th) * (0.0 if va == "top" else (1.0 if va == "bottom" else 0.5))
	var icon_rect: Rect2
	var tx: float
	var ty: float
	var text_align: String = spec.get("text_align", "left" if layout == "h" else "center")
	if layout == "h":
		icon_rect = Rect2(ox, oy + (th - icon_px) * 0.5, icon_px, icon_px)
		tx = ox + icon_px + gap_px
		ty = oy + (th - block_h) * 0.5
	else:
		var ix := ox + (tw - icon_px) * 0.5
		if text_align == "left":
			ix = ox
		icon_rect = Rect2(ix, oy, icon_px, icon_px)
		tx = ox
		ty = oy + icon_px + gap_px
	var font_tr := tracked(file, int(round(track * fs)))
	var line_ws: Array = m[1]
	var shadow: Array = spec.get("shadow", [])
	var draw_all := func(cc: CanvasItem, off: Vector2, tint: Color) -> void:
		if has_icon:
			_draw_icon(cc, icon, Rect2(icon_rect.position + off, icon_rect.size), tint)
		for li in lines.size():
			var lx := tx
			if text_align == "center":
				lx = tx + (block_w - line_ws[li]) * 0.5
			var base_y := ty + cap * fs * (li + 1) + line_gap * fs * li
			var x := lx
			var sp := text_w(font_tr, " ", fs) + word_gap * fs
			for seg in lines[li]:
				var col: Color = seg[1] if tint.a == 0.0 else tint
				cc.draw_string(font_tr, Vector2(x, base_y) + off, seg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
				x += text_w(font_tr, seg[0], fs) + sp
			if cursor.a > 0.0 and li == lines.size() - 1:
				var ccol: Color = cursor if tint.a == 0.0 else tint
				cc.draw_rect(Rect2(Vector2(x - sp + fs * 0.1, base_y - cap * fs) + off, Vector2(fs * 0.52, cap * fs)), ccol)
	if spec.get("dry", false):
		return Rect2(ox, oy, tw, th)
	if shadow.size() == 2:
		var rad: float = shadow[0] * fs
		var drop := Vector2(0, rad * 0.35)
		if has_icon:
			soft(c, func(cc, off, tint): _draw_icon(cc, icon, Rect2(icon_rect.position + off + drop, icon_rect.size), tint), rad, shadow[1])
		# Text shadow from stacked, growing outlines: a smooth falloff with no
		# offset ghost copies of the letters.
		var steps := 12
		var per := 1.0 - pow(1.0 - float(shadow[1]), 1.0 / steps)
		for step in steps:
			var osz := int(round(rad * 2.0 * (step + 1) / steps))
			for li in lines.size():
				var lx := tx
				if text_align == "center":
					lx = tx + (block_w - line_ws[li]) * 0.5
				var base_y := ty + cap * fs * (li + 1) + line_gap * fs * li
				var x := lx
				var sp := text_w(font_tr, " ", fs) + word_gap * fs
				for seg in lines[li]:
					c.draw_string_outline(font_tr, Vector2(x, base_y) + drop, seg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, osz, Color(0, 0, 0, per))
					x += text_w(font_tr, seg[0], fs) + sp
	draw_all.call(c, Vector2.ZERO, Color(0, 0, 0, 0))
	return Rect2(ox, oy, tw, th)


static func _measure(lines: Array, file: String, track: float, fs: int, cursor: bool = false, word_gap: float = 0.0) -> Array:
	var f := tracked(file, int(round(track * fs)))
	var sp := text_w(f, " ", fs) + word_gap * fs
	var widths: Array = []
	var mx := 0.0
	for line in lines:
		var w := 0.0
		for i in line.size():
			w += text_w(f, line[i][0], fs)
			if i < line.size() - 1:
				w += sp
		if cursor and widths.size() == lines.size() - 1:
			w += fs * 0.62
		widths.append(w)
		mx = maxf(mx, w)
	return [mx, widths]


static func _draw_icon(c: CanvasItem, icon, r: Rect2, tint: Color) -> void:
	var shadow := tint.a > 0.0
	if icon is Callable:
		icon.call(c, r, tint)
		return
	var px := int(ceil(r.size.x))
	var mod := tint if shadow else Color.WHITE
	match icon:
		"tile":
			c.draw_texture_rect(icon_tile_tex(px), r, false, mod)
		"clover":
			c.draw_texture_rect(clover_tex(px), r, false, mod)
		"white":
			c.draw_texture_rect(clover_tex(px, "#ffffff", ""), r, false, mod)
		"outline":
			c.draw_texture_rect(clover_tex(px, "none", "#ffffff", 22.0), r, false, mod)
		"badge":
			badge(c, r, tint)


## Glossy round badge with a white clover (Soundpad-style).
static func badge(c: CanvasItem, r: Rect2, tint: Color = Color(0, 0, 0, 0)) -> void:
	var ctr := r.get_center()
	var rad := r.size.x * 0.5
	if tint.a > 0.0:
		c.draw_circle(ctr, rad, tint, true, -1.0, true)
		return
	# Outer ring + radial body (stacked circles give the gradient).
	c.draw_circle(ctr, rad, Color("#9fd4ff"), true, -1.0, true)
	var steps := 40
	for k in steps:
		var t := float(k) / (steps - 1)
		var col := Color("#2d6fb0").lerp(Color("#56b0ff"), t)
		var rr := rad * 0.955 * (1.0 - t * 0.55)
		c.draw_circle(ctr + Vector2(0, -rad * 0.18 * t), rr, col, true, -1.0, true)
	var cl := r.size.x * 0.62
	c.draw_texture_rect(clover_tex(int(cl), "#ffffff", ""), Rect2(ctr - Vector2(cl, cl) * 0.5 + Vector2(0, rad * 0.02), Vector2(cl, cl)), false)
	# Gloss.
	var pts := PackedVector2Array()
	for k in 33:
		var a := PI + PI * k / 32.0
		pts.append(ctr + Vector2(cos(a) * rad * 0.82, sin(a) * rad * 0.62 - rad * 0.05))
	c.draw_colored_polygon(pts, Color(1, 1, 1, 0.10))


## Neutral stand-in for a platform icon (no OS trademarks in store art):
## a tinted rounded tile with a simple monitor/laptop/terminal glyph.
static func platform_glyph(c: CanvasItem, r: Rect2, idx: int) -> void:
	var cols := [Color("#3d86dc"), Color("#9aa4b2"), Color("#d9a64a")]
	rrect(c, r, r.size.x * 0.22, Color(cols[idx % 3], 0.9))
	var w := maxf(1.0, r.size.x * 0.09)
	var inner := r.grow(-r.size.x * 0.24)
	match idx % 3:
		0:
			c.draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.7)), Color.WHITE, false, w)
			c.draw_line(Vector2(inner.get_center().x, inner.position.y + inner.size.y * 0.7), Vector2(inner.get_center().x, inner.end.y), Color.WHITE, w)
		1:
			c.draw_rect(Rect2(inner.position + Vector2(inner.size.x * 0.1, 0), Vector2(inner.size.x * 0.8, inner.size.y * 0.66)), Color.WHITE, false, w)
			c.draw_line(Vector2(inner.position.x, inner.end.y - w), Vector2(inner.end.x, inner.end.y - w), Color.WHITE, w * 1.4)
		2:
			c.draw_polyline(PackedVector2Array([inner.position + Vector2(0, inner.size.y * 0.2), inner.position + Vector2(inner.size.x * 0.4, inner.size.y * 0.5), inner.position + Vector2(0, inner.size.y * 0.8)]), Color.WHITE, w, true)
			c.draw_line(inner.position + Vector2(inner.size.x * 0.5, inner.size.y * 0.85), inner.end - Vector2(0, inner.size.y * 0.15), Color.WHITE, w)


## Darkens the hero's bottom-left, where Steam lays the library logo.
static func calm_corner(c: CanvasItem, s: Vector2, col: Color = Color(0.03, 0.04, 0.06, 0.8)) -> void:
	c.draw_set_transform(Vector2(s.x * 0.16, s.y * 0.82), 0.0, Vector2(1.6, 1.0))
	glow(c, Vector2.ZERO, s.y * 0.75, col, 40)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Invented projects -------------------------------------------------------

const PROJECTS := [
	["Moss & Mortar", "4.5", Color("#6fae5b")],
	["Pocket Kraken", "4.4", Color("#d4665c")],
	["Tiny Lantern", "4.5", Color("#e0b44c")],
	["Orbit Bakery", "4.3", Color("#c77dcf")],
	["Cinder Knights", "4.5", Color("#e0874c")],
	["Hollow Pines", "4.2", Color("#4fa38f")],
	["Neon Burrow", "4.5", Color("#5a7de0")],
	["Starfall Farm", "4.4", Color("#e0c96b")],
	["Rust Runner", "4.1", Color("#b0724a")],
	["Glimmer Deep", "4.5", Color("#4cb4d4")],
]


## Little generated game icon: rounded tile with a simple glyph.
static func project_icon(c: CanvasItem, r: Rect2, idx: int) -> void:
	var col: Color = PROJECTS[idx % PROJECTS.size()][2]
	rrect(c, r, r.size.x * 0.24, col.darkened(0.35))
	var ctr := r.get_center()
	var s := r.size.x
	var light := col.lightened(0.25)
	match idx % 5:
		0:
			c.draw_circle(ctr, s * 0.26, light, true, -1.0, true)
		1:
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -s * 0.3), ctr + Vector2(s * 0.28, s * 0.22), ctr + Vector2(-s * 0.28, s * 0.22)]), light)
		2:
			c.draw_rect(Rect2(ctr - Vector2(s, s) * 0.2, Vector2(s, s) * 0.4), light)
		3:
			c.draw_circle(ctr + Vector2(-s * 0.12, 0), s * 0.18, light, true, -1.0, true)
			c.draw_circle(ctr + Vector2(s * 0.14, s * 0.05), s * 0.13, col.lightened(0.5), true, -1.0, true)
		4:
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI / 2 + TAU * k / 10.0
				var rad := s * (0.3 if k % 2 == 0 else 0.13)
				pts.append(ctr + Vector2(cos(a), sin(a)) * rad)
			c.draw_colored_polygon(pts, light)


## Mini invented capsule art (dusk sky, moon, hills) for the Steam card.
static func mini_capsule(c: CanvasItem, r: Rect2, radius: float) -> void:
	rrect(c, r, radius, Color("#1d2b4f"))
	var inner := r.grow(-radius * 0.35)
	var sky := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)])
	c.draw_polygon(sky, PackedColorArray([Color("#2b3f73"), Color("#2b3f73"), Color("#d77a61"), Color("#d77a61")]))
	c.draw_circle(inner.position + inner.size * Vector2(0.68, 0.28), inner.size.x * 0.13, Color("#f6e3b0"), true, -1.0, true)
	var hill := PackedVector2Array()
	for k in 13:
		var t := k / 12.0
		hill.append(Vector2(inner.position.x + inner.size.x * t, inner.position.y + inner.size.y * (0.66 - 0.08 * sin(t * 5.0))))
	hill.append(inner.end)
	hill.append(Vector2(inner.position.x, inner.end.y))
	c.draw_colored_polygon(hill, Color("#233a2e"))
	var hill2 := PackedVector2Array()
	for k in 13:
		var t := k / 12.0
		hill2.append(Vector2(inner.position.x + inner.size.x * t, inner.position.y + inner.size.y * (0.8 - 0.06 * cos(t * 7.0))))
	hill2.append(inner.end)
	hill2.append(Vector2(inner.position.x, inner.end.y))
	c.draw_colored_polygon(hill2, Color("#16261d"))


# --- Console -----------------------------------------------------------------

## Console log model: [kind, stamp, text, extra]. kind: step | cmd | out | bar |
## ok | done | info. For bar: extra = [pct, color].
static func console_lines(game: String = "MossAndMortar") -> Array:
	return [
		["step", "12:26:05", "▸ Checking depots on Steam", null],
		["out", "12:26:07", "Waiting for user info...OK", null],
		["done", "12:26:08", "√ Done · 2.3s", null],
		["gap"],
		["step", "12:26:08", "▸ Exporting 'Windows Desktop' as %s.exe → depot 1840211" % game, null],
		["cmd", "12:26:08", "$ godot --headless --export-release \"Windows Desktop\"", null],
		["bar", "12:26:08", "Windows Desktop", [1.0, GREEN]],
		["done", "12:26:08", "√ Done · 0.7s", null],
		["gap"],
		["step", "12:26:09", "▸ Exporting 'macOS' as %s.zip → depot 1840212" % game, null],
		["bar", "12:26:09", "macOS", [1.0, GREEN]],
		["done", "12:26:09", "√ Done · 0.7s", null],
		["gap"],
		["step", "12:26:09", "▸ Exporting 'Linux' as %s.x86_64 → depot 1840213" % game, null],
		["bar", "12:26:10", "Linux", [1.0, GREEN]],
		["done", "12:26:10", "√ Done · 0.7s", null],
		["gap"],
		["step", "12:26:10", "▸ Uploading to Steam", null],
		["cmd", "12:26:10", "$ steamcmd +run_app_build app_build.vdf +quit", null],
		["bar", "12:26:11", "Depot 1840211 (Windows)", [1.0, GREEN]],
		["bar", "12:26:11", "Depot 1840212 (macOS)", [1.0, GREEN]],
		["bar", "12:26:12", "Depot 1840213 (Linux)", [0.55, CMD]],
		["ok", "12:26:12", "Upload complete and set live on branch 'beta'.", null],
		["done", "12:26:12", "√ Done · 1.7s", null],
	]


## Draws console lines into rect. fs = mono font size in px. greek = draw
## text as rounded pills (for the library hero, which must not contain text).
## alpha multiplies everything. Returns the y after the last line.
static func console(c: CanvasItem, rect: Rect2, lines: Array, fs: float, alpha: float = 1.0, greek: bool = false, start: int = 0) -> float:
	var f := font("IBMPlexMono-Regular")
	var fsi := int(round(fs))
	var lh := fs * 2.05
	var y := rect.position.y + lh * 0.72
	var x0 := rect.position.x
	var stamp_w := text_w(f, "12:26:08", fsi) + fs * 1.3
	var gutter_x := x0 + stamp_w
	var body_x := gutter_x + fs * 1.2
	var li := start
	while y < rect.end.y + lh:
		var ln: Array = lines[li % lines.size()]
		li += 1
		if ln[0] == "gap":
			y += lh * 0.6
			continue
		var kind: String = ln[0]
		_mono(c, f, ln[1], Vector2(x0, y), fsi, _a(STAMP, alpha * 0.9), greek)
		var col := TEXT_2
		match kind:
			"step":
				col = TEXT
			"cmd":
				col = CMD
			"ok", "done":
				col = GREEN
			"out":
				col = MUTED
		if kind in ["cmd", "bar", "out"]:
			c.draw_line(Vector2(gutter_x, y - fs * 1.0), Vector2(gutter_x, y + fs * 0.55), _a(GUTTER, alpha * 1.4), maxf(1.0, fs * 0.09))
		var tx := body_x if kind in ["cmd", "bar", "out"] else gutter_x
		if kind == "cmd":
			var w := text_w(f, ln[2], fsi) if not greek else text_w(f, ln[2], fsi)
			rrect(c, Rect2(tx - fs * 0.45, y - fs * 1.02, minf(w + fs * 0.9, rect.end.x - tx + fs * 0.45), fs * 1.5), fs * 0.25, _a(Color(CMD, 0.09), alpha))
		if kind == "bar":
			var label: String = ln[2]
			_mono(c, f, label, Vector2(tx, y), fsi, _a(TEXT_2, alpha), greek)
			var bx := tx + maxf(text_w(f, label, fsi), text_w(f, "Windows Desktop", fsi)) + fs * 1.4
			if text_w(f, "Depot 1840211 (Windows)", fsi) + fs * 1.4 + tx + fs * 18.0 < rect.end.x:
				bx = tx + text_w(f, "Depot 1840211 (Windows)", fsi) + fs * 1.4
			var bw := minf(rect.end.x - bx - fs * 4.2, fs * 12.0)
			var pct: float = ln[3][0]
			var bcol: Color = ln[3][1]
			if bw > fs * 2.0:
				progress_cells(c, Rect2(bx, y - fs * 0.78, bw, fs * 0.9), pct, _a(bcol, alpha), _a(GUTTER, alpha * 1.2), 20, 0.12)
				_mono(c, f, "%d%%" % int(pct * 100), Vector2(bx + bw + fs * 0.8, y), fsi, _a(GREEN if pct >= 1.0 else TEXT_2, alpha), greek)
		else:
			_mono(c, f, ln[2], Vector2(tx, y), fsi, _a(col, alpha), greek, rect.end.x - tx)
		y += lh
		if li - start > 400:
			break
	return y


static func _a(col: Color, alpha: float) -> Color:
	return Color(col.r, col.g, col.b, clampf(col.a * alpha, 0.0, 1.0))


static func _mono(c: CanvasItem, f: Font, t: String, pos: Vector2, fs: int, col: Color, greek: bool, max_w: float = -1.0) -> void:
	if not greek:
		if max_w > 0 and text_w(f, t, fs) > max_w:
			while t.length() > 1 and text_w(f, t + "…", fs) > max_w:
				t = t.substr(0, t.length() - 1)
			t = t.strip_edges() + "…"
		c.draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		return
	# Greeked: one pill per word.
	var x := pos.x
	var sp := text_w(f, " ", fs)
	for w in t.split(" "):
		if w == "":
			x += sp
			continue
		var ww := text_w(f, w, fs)
		if max_w > 0 and x + ww > pos.x + max_w:
			break
		rrect(c, Rect2(x, pos.y - fs * 0.62, ww, fs * 0.5), fs * 0.25, col)
		x += ww + sp


# --- App window mock ---------------------------------------------------------

## Draws a stylised Godot To Steam window. Coordinates are app pixels (the
## window is 1440x900) scaled by k, with the top-left at origin and rotation
## rot. Text is drawn at fs*k so it stays sharp. greek swaps text for pills.
static func app_window(c: CanvasItem, origin: Vector2, k: float, rot: float = 0.0, greek: bool = false, opts: Dictionary = {}) -> void:
	c.draw_set_transform(origin, rot, Vector2.ONE)
	var W := 1440.0
	var H := 900.0
	var ui := font("Inter-Regular")
	var ui_sb := font("Inter-SemiBold")
	var P := func(x: float, y: float) -> Vector2: return Vector2(x, y) * k
	var R := func(x: float, y: float, w: float, h: float) -> Rect2: return Rect2(x * k, y * k, w * k, h * k)
	var T := func(f: Font, t: String, x: float, y: float, fs: float, col: Color) -> void:
		if greek:
			var w := text_w(f, t, int(fs * k))
			rrect(c, Rect2(x * k, (y - fs * 0.62) * k, w, fs * 0.52 * k), fs * 0.26 * k, Color(col, col.a * 0.55))
		else:
			c.draw_string(f, Vector2(x, y) * k, t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(fs * k)), col)
	# Window body + shadow.
	var shadow_a: float = opts.get("shadow", 0.55)
	if shadow_a > 0.0:
		rrect(c, R.call(0, 0, W, H), 16 * k, Color(0, 0, 0, 0), 0, Color.TRANSPARENT, int(60 * k), Color(0, 0, 0, shadow_a), Vector2(0, 24 * k))
	rrect(c, R.call(0, 0, W, H), 16 * k, APP_BG, 1.5 * k, BORDER_STRONG)
	# Sidebar.
	var sb := StyleBoxFlat.new()
	sb.bg_color = SIDEBAR
	sb.corner_radius_top_left = int(16 * k)
	sb.corner_radius_bottom_left = int(16 * k)
	sb.anti_aliasing = true
	c.draw_style_box(sb, R.call(1, 1, 259, H - 2))
	var nav_y := 58.0
	var nav: Array = [["add", "Add app"], ["script", "Console"], ["arrow_down", "SteamCMD"]]
	for i in nav.size():
		if i == 1:
			rrect(c, R.call(12, nav_y - 22 + i * 42, 236, 38), 8 * k, CARD)
		c.draw_texture_rect(editor_icon_tex(nav[i][0], int(16 * k)), R.call(26, nav_y - 11 + i * 42, 16, 16), false, Color(TEXT, 0.85))
		T.call(ui, nav[i][1], 52, nav_y + 5 + i * 42, 14.5, TEXT if i == 1 else TEXT_2)
	T.call(ui_sb, "Apps", 24, 212, 13.5, MUTED)
	c.draw_texture_rect(editor_icon_tex("add", int(16 * k)), R.call(222, 200, 16, 16), false, Color(MUTED, 0.9))
	var sel: int = opts.get("selected", 0)
	for i in 10:
		var y := 250.0 + i * 45.0
		if i == sel:
			rrect(c, R.call(12, y - 22, 236, 40), 8 * k, CARD)
		project_icon(c, R.call(24, y - 10, 20, 20), i)
		T.call(ui, PROJECTS[i][0], 56, y + 5, 14.5, TEXT if i == sel else TEXT_2)
		T.call(ui, PROJECTS[i][1], 214, y + 5, 13, MUTED)
	# Account footer.
	c.draw_line(P.call(1, H - 70), P.call(259, H - 70), BORDER, maxf(1.0, k))
	c.draw_circle(P.call(38, H - 36), 15 * k, ACCENT, true, -1.0, true)
	T.call(ui_sb, "M", 33, H - 31, 13, Color.WHITE)
	T.call(ui_sb, "mira_dev", 64, H - 40, 14, TEXT)
	T.call(ui, "Signed in", 64, H - 21, 12.5, MUTED)
	# Main column.
	var mx := 290.0
	var mw := 760.0
	var game: Array = PROJECTS[sel]
	project_icon(c, R.call(mx, 38, 28, 28), sel)
	T.call(ui_sb, game[0], mx + 42, 61, 22, TEXT)
	T.call(ui, "Remove", mx + mw - 58, 58, 14, TEXT_2)
	# Godot card.
	T.call(ui_sb, "Godot", mx, 124, 14, TEXT_2)
	rrect(c, R.call(mx, 140, mw, 104), 10 * k, CARD)
	T.call(ui, "Status", mx + 20, 176, 14, TEXT_2)
	c.draw_circle(P.call(mx + 170, 171), 4 * k, GREEN, true, -1.0, true)
	T.call(ui, "Ready to export", mx + 184, 176, 14, TEXT)
	T.call(ui, "Binary", mx + 20, 218, 14, TEXT_2)
	rrect(c, R.call(mx + 164, 196, mw - 190, 34), 6 * k, INPUT, 1.0 * k, BORDER)
	T.call(ui, "/Applications/Godot.app/Contents/MacOS/Godot", mx + 176, 218, 14, TEXT)
	# Steam card with capsule.
	T.call(ui_sb, "Steam", mx, 290, 14, TEXT_2)
	mini_capsule(c, R.call(mx, 306, 84, 124), 10 * k)
	rrect(c, R.call(mx + 100, 306, mw - 100, 124), 10 * k, CARD)
	T.call(ui, "App ID", mx + 122, 350, 14, TEXT_2)
	rrect(c, R.call(mx + 320, 328, mw - 440, 34), 6 * k, INPUT, 1.0 * k, BORDER)
	T.call(ui, "1840210", mx + 332, 350, 14, TEXT)
	T.call(ui, "Set live on branch", mx + 122, 402, 14, TEXT_2)
	rrect(c, R.call(mx + 320, 380, mw - 440, 34), 6 * k, INPUT, 1.0 * k, BORDER)
	T.call(ui, "beta", mx + 332, 402, 14, TEXT)
	# Depots.
	T.call(ui_sb, "Depots", mx, 478, 14, TEXT_2)
	rrect(c, R.call(mx, 494, mw, 188), 10 * k, CARD)
	T.call(ui, "Export preset", mx + 20, 526, 13, MUTED)
	T.call(ui, "Depot ID", mx + 330, 526, 13, MUTED)
	T.call(ui, "Executable", mx + 520, 526, 13, MUTED)
	var plats: Array = [["", "Windows Desktop", ".exe"], ["", "macOS", ".app"], ["", "Linux", ".x86_64"]]
	var exe: String = String(game[0]).replace(" ", "").replace("&", "And")
	for i in plats.size():
		var y := 542.0 + i * 44.0
		rrect(c, R.call(mx + 16, y, 300, 34), 6 * k, INPUT, 1.0 * k, BORDER)
		platform_glyph(c, R.call(mx + 27, y + 7, 20, 20), i)
		T.call(ui, plats[i][1], mx + 56, y + 22, 14, TEXT)
		rrect(c, R.call(mx + 326, y, 180, 34), 6 * k, INPUT, 1.0 * k, BORDER)
		T.call(ui, str(1840211 + i), mx + 338, y + 22, 14, TEXT)
		rrect(c, R.call(mx + 516, y, 224, 34), 6 * k, INPUT, 1.0 * k, BORDER)
		T.call(ui, exe + plats[i][2], mx + 528, y + 22, 14, TEXT)
	# Composer.
	rrect(c, R.call(mx, H - 92, mw, 64), 12 * k, COMPOSER, 1.0 * k, Color("#2a2a2a"))
	T.call(ui, "Early Access update", mx + 20, H - 54, 15, TEXT)
	rrect(c, R.call(mx + mw - 52, H - 80, 40, 40), 8 * k, ACCENT)
	c.draw_texture_rect(editor_icon_tex("main_play", int(18 * k)), R.call(mx + mw - 41, H - 69, 18, 18), false)
	# Console dock.
	var cx := 1080.0
	var cw := W - cx - 16.0
	rrect(c, R.call(cx, 16, cw, H - 32), 12 * k, CONSOLE, 1.0 * k, BORDER)
	T.call(ui, "Console", cx + 18, 46, 14, TEXT_2)
	c.draw_line(P.call(cx, 64), P.call(cx + cw, 64), BORDER, maxf(1.0, k))
	var clines: Array = opts.get("console", console_lines(exe))
	var cf := 12.0 * k
	c.draw_set_transform(origin, rot, Vector2.ONE)
	var crect := Rect2(P.call(cx + 16, 72), Vector2((cw - 28) * k, (H - 120) * k))
	# Console text uses its own clip-free layout; keep lines short enough.
	console(c, crect, clines, cf, 1.0, greek, opts.get("console_start", 13))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
