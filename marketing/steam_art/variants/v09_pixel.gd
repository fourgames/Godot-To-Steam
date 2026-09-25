extends "res://marketing/steam_art/variant_base.gd"
## 09 Pixel Clover (Lossless Scaling): the clover as chunky pixel art with a
## hand-set pixel wordmark on a night-sky navy
## (the app icon's tile colour), dotted with pixel stars. Pixel sizes are kept to even
## numbers so every art pixel lands on whole pixels after the 2x downscale.

const SKY_A := Color("#1b2a4a")
const SKY_B := Color("#0d1428")
const INK := Color("#070b16")

## 5x7 pixel glyphs for the title.
const GLYPHS := {
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
}

const CLOUD := ["...####.....", ".########.##", "############", ".##########."]

var _grids := {}
## Base pixel size of the last lockup, so stars sit on the same grid.
var _cell := 2.0


func _init() -> void:
	id = "09"
	title = "Pixel Clover"
	inspired_by = "Lossless Scaling"
	page_blur = 0.0


static func even(v: float) -> float:
	return maxf(2.0, floor(v / 2.0) * 2.0)


## Hand-built pixel clover on an n x n grid: four heart leaves pointing at
## the centre, split by a cross-shaped gap like the app icon. 0 empty, 1 fill,
## 2 outline.
func grid(n: int) -> Array:
	if _grids.has(n):
		return _grids[n]
	var ctr := Vector2(n, n) * 0.5
	var g: Array = []
	for y in n:
		var row: Array = []
		for x in n:
			row.append(0)
		g.append(row)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var q := p - ctr
			if absf(q.x) < 1.6 or absf(q.y) < 1.6 or absf(q.x) + absf(q.y) < n * 0.2:
				continue
			for d0 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var d: Vector2 = d0.normalized()
				var perp := Vector2(-d.y, d.x)
				var rad := n * 0.118
				var l1 := ctr + d * n * 0.3 + perp * n * 0.125
				var l2 := ctr + d * n * 0.3 - perp * n * 0.125
				var along := q.dot(d)
				var across := q.dot(perp)
				var in_tip := along > 0.0 and along < n * 0.3 and absf(across) < (along / (n * 0.3)) * (n * 0.125 + rad * 0.9)
				if p.distance_to(l1) < rad or p.distance_to(l2) < rad or in_tip:
					g[y][x] = 1
					break
	for y in n:
		for x in n:
			if g[y][x] != 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx: int = x + d.x
				var yy: int = y + d.y
				if xx >= 0 and yy >= 0 and xx < n and yy < n and g[yy][xx] == 1:
					g[y][x] = 2
					break
	_grids[n] = g
	return g


func pixel_clover(c: CanvasItem, pos: Vector2, cell: float, n: int, palette: String = "blue", shadow := true) -> void:
	var g := grid(n)
	if shadow:
		for y in n:
			for x in n:
				if g[y][x] != 0:
					c.draw_rect(Rect2(pos + Vector2(x + 1, y + 1) * cell, Vector2(cell, cell)), Color(INK, 0.55))
	for y in n:
		for x in n:
			var v: int = g[y][x]
			if v == 0:
				continue
			var col := Color.WHITE
			if v == 1:
				var t := (x + y) / float(2 * n)
				if palette == "blue":
					col = Color("#8fd3ff") if t < 0.36 else (Color("#56b0ff") if t < 0.6 else Color("#3d86dc"))
				else:
					col = Color("#9be38f") if t < 0.36 else (Color("#5cbf5a") if t < 0.6 else Color("#3f9a45"))
				if y > 0 and g[y - 1][x] == 2 and t < 0.6:
					col = col.lightened(0.25)
			elif palette != "blue":
				col = Color("#e8ffe0")
			c.draw_rect(Rect2(pos + Vector2(x, y) * cell, Vector2(cell, cell)), col)


func text_cells(line: String) -> int:
	var w := 0
	for i in line.length():
		var ch := line[i]
		w += 3 if ch == " " else 5
		if i < line.length() - 1:
			w += 1
	return w


var outline_text := false


func pixel_text(c: CanvasItem, pos: Vector2, cell: float, line: String, col: Color, shadow := true) -> void:
	var on := {}
	var x := 0
	for ch in line:
		if ch == " ":
			x += 4
			continue
		var rows: Array = GLYPHS[ch]
		for y in 7:
			for gx in 5:
				if rows[y][gx] == "#":
					on[Vector2i(x + gx, y)] = true
		x += 6
	if shadow and outline_text:
		# Small sizes: a dark outline all round reads better than an extrude.
		for p in on:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q: Vector2i = p + Vector2i(dx, dy)
					if not on.has(q):
						c.draw_rect(Rect2(pos + Vector2(q) * cell, Vector2(cell, cell)), Color("#0a1024"))
	elif shadow:
		# Chunky drop shadow down-right; letter holes stay clear.
		for p in on:
			for d in [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var q: Vector2i = p + Vector2i(d)
				if not on.has(q):
					c.draw_rect(Rect2(pos + Vector2(q) * cell, Vector2(cell, cell)), Color("#2a5aa0"))
	for p in on:
		c.draw_rect(Rect2(pos + Vector2(p) * cell, Vector2(cell, cell)), col)


## Clover + two-line pixel wordmark (letters at twice the clover's pixel
## size) + pixel progress bar. Returns bounds.
func pixel_lockup(c: CanvasItem, r: Rect2, vertical: bool, bar: bool, halign := "center", n := 44, dry := false) -> Rect2:
	var lines := ["GODOT TO", "STEAM"]
	var ts := 2
	var tw := maxi(text_cells(lines[0]), text_cells(lines[1])) * ts
	var th := (7 * 2 + 3) * ts + (4 * ts if bar else 0)
	var gap := 6
	var W: int
	var H: int
	var cn := n
	if vertical:
		W = maxi(cn, tw)
		H = cn + gap + th
	else:
		W = cn + gap + tw
		H = maxi(cn, th)
	var cell := even(minf(r.size.x / (W + 2), r.size.y / (H + 2)))
	_cell = cell
	var size := Vector2(W, H) * cell
	var o := r.position + (r.size - size) * Vector2(0.0 if halign == "left" else 0.5, 0.5)
	o = Vector2(even(o.x), even(o.y))
	if dry:
		return Rect2(o, size)
	var icon_pos: Vector2
	var text_pos: Vector2
	if vertical:
		icon_pos = o + Vector2(floor((W - cn) * 0.5), 0) * cell
		text_pos = o + Vector2(floor((W - tw) * 0.5), cn + gap) * cell
	else:
		icon_pos = o + Vector2(0, floor((H - cn) * 0.5)) * cell
		text_pos = o + Vector2(cn + gap, floor((H - th) * 0.5)) * cell
	pixel_clover(c, icon_pos, cell, n)
	var tcell := cell * ts
	for li in 2:
		var lx: float = floorf((tw / float(ts) - text_cells(lines[li])) * 0.5) if vertical else 0.0
		pixel_text(c, text_pos + Vector2(lx, li * 10) * tcell, tcell, lines[li], Color.WHITE)
	if bar:
		# 20-cell bar, 16 filled: the app's progress bar mid-upload.
		var by := text_pos.y + 20 * tcell + tcell * 0.5
		var cw := float(tw) / 20.0
		for k in 20:
			var cx := text_pos.x + floorf(k * cw) * cell
			var w := maxf(cell, floor(cw * 0.75) * cell)
			var col := L.GREEN.lightened(0.1) if k < 16 else Color("#2a3a5a")
			c.draw_rect(Rect2(Vector2(cx + cell, by + cell), Vector2(w, tcell * 1.5)), INK)
			c.draw_rect(Rect2(Vector2(cx, by), Vector2(w, tcell * 1.5)), col)
	return Rect2(o, size)


func stars(c: CanvasItem, s: Vector2, cell: float, density: float, avoid: Rect2 = Rect2()) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 993090
	var n := int(s.x * s.y / pow(s.y * 0.08, 2.0) * density)
	for i in n:
		var p := Vector2(even(rng.randf() * s.x), even(rng.randf() * s.y))
		if avoid.has_point(p):
			continue
		var a := rng.randf_range(0.3, 0.9)
		var col := Color(1, 1, 1, a) if rng.randf() < 0.75 else Color("#8fd3ff", a)
		c.draw_rect(Rect2(p, Vector2(cell, cell)), col)
		if rng.randf() < 0.18:
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				c.draw_rect(Rect2(p + d * cell, Vector2(cell, cell)), Color(col, a * 0.5))


func clouds(c: CanvasItem, s: Vector2, spots: Array, cell: float) -> void:
	for sp in spots:
		var p := Vector2(even(s.x * sp.x), even(s.y * sp.y))
		for y in CLOUD.size():
			for x in CLOUD[y].length():
				if CLOUD[y][x] == "#":
					c.draw_rect(Rect2(p + Vector2(x, y) * cell, Vector2(cell, cell)), Color(1, 1, 1, 0.9 if y < 3 else 0.75))


## Grass strip from gy down with little green clovers from x0 on.
func grass(c: CanvasItem, s: Vector2, gy: float, cell: float, x0: float, seed: int, big := true) -> void:
	c.draw_rect(Rect2(0, gy, s.x, s.y - gy), Color("#1f4a2a"))
	c.draw_rect(Rect2(0, gy, s.x, cell * 2), Color("#2f6b3a"))
	var x := 0.0
	var k := 0
	while x < s.x:
		if k % 3 != 1:
			c.draw_rect(Rect2(x, gy - cell, cell, cell), Color("#2f6b3a"))
		x += cell * 2
		k += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var px := x0
	while px < s.x:
		var n := 12
		var sc := cell * (1.0 if rng.randf() < 0.6 or not big else 2.0)
		var h := rng.randi_range(2, 6)
		var base := Vector2(even(px), gy - h * sc)
		if px + n * sc > s.x - cell:
			break
		c.draw_rect(Rect2(base + Vector2(n * 0.5 - 0.5, 0) * sc, Vector2(sc, h * sc)), Color("#2f7a37"))
		pixel_clover(c, base - Vector2(0, n - 2) * sc, sc, n, "green", false)
		px += n * sc + cell * rng.randi_range(4, 20)


func _sky(root: Control) -> void:
	L.add_bg(root, {"a": SKY_A, "b": SKY_B, "noise": 0.6})


func background(root: Control, s: Vector2, mode: String) -> void:
	_sky(root)
	L.add_draw(root, func(c: Control) -> void:
		var cell := even(s.y * 0.01)
		if mode == "page":
			# Ambient: just a dim starfield.
			stars(c, s, cell, 0.7)
			c.draw_rect(Rect2(Vector2.ZERO, s), Color(SKY_B, 0.45))
			return
		stars(c, s, cell, 1.0, Rect2(0, s.y * 0.5, s.x * 0.42, s.y * 0.5))
		grass(c, s, even(s.y * 0.9), cell, s.x * 0.45, 993091))


func capsule(root: Control, kind: String, s: Vector2) -> void:
	_sky(root)
	var r: Rect2
	var vertical := false
	var n := 44
	if kind == "small":
		r = fr(s, 0.02, 0.04, 0.96, 0.92)
		n = 30
	elif tall(s):
		r = fr(s, 0.08, 0.14, 0.84, 0.62)
		vertical = true
	else:
		r = fr(s, 0.05, 0.12, 0.9, 0.76)
	L.add_draw(root, func(c: Control) -> void:
		var b := pixel_lockup(c, r, vertical, false, "center", n, true)
		stars(c, s, _cell, 0.5 if kind != "small" else 0.3, b.grow(_cell * 3.0))
		if tall(s):
			grass(c, s, even(s.y * 0.92), _cell, s.x * 0.04, 993092, false)
		outline_text = kind == "small"
		pixel_lockup(c, r, vertical, false, "center", n))


func logo(root: Control, s: Vector2) -> void:
	L.add_draw(root, func(c: Control) -> void:
		pixel_lockup(c, Rect2(Vector2(s.y * 0.1, s.y * 0.1), s - Vector2(s.y, s.y) * 0.2), false, false))
