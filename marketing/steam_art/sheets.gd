extends RefCounted
## Comparison sheets for picking a favourite: every variant side by side per
## asset size, one board per variant with all its sizes, the library view
## (hero + logo like the Steam client) and the small capsule at list sizes.

const L := preload("res://marketing/steam_art/lib.gd")
const DrawLayer := preload("res://marketing/steam_art/draw_layer.gd")

const SHEET_BG := Color("#0f1115")
const STEAM_BG := Color("#1b2838")

var _host: Node
var _count := 10


func build(host: Node, root_dir: String, variant_paths: Array, dir_name: String = "_compare") -> void:
	_host = host
	var out := root_dir + "/" + dir_name
	DirAccess.make_dir_recursive_absolute(out)
	var vs: Array = []
	for path in variant_paths:
		if not ResourceLoader.exists(path):
			continue
		var v = load(path).new()
		var dir := "%s/%s %s" % [root_dir, v.id, v.title]
		vs.append({"id": v.id, "title": v.title, "ref": v.inspired_by, "dir": dir})
	_count = vs.size()
	# Per-size comparisons.
	var grids := {
		"header_capsule": [2, 560.0, "Header capsule · 920×430"],
		"main_capsule": [2, 560.0, "Main capsule · 1232×706"],
		"small_capsule": [2, 462.0, "Small capsule · 462×174 (actual size)"],
		"vertical_capsule": [5, 300.0, "Vertical capsule · 748×896"],
		"library_capsule": [5, 300.0, "Library capsule · 600×900 (shown at Steam's 300×450)"],
		"library_header": [2, 560.0, "Library header · 920×430"],
		"library_hero": [2, 800.0, "Library hero · 3840×1240 (dashed: 860×380 safe area)"],
		"library_logo": [2, 560.0, "Library logo · transparent PNG"],
		"page_background": [2, 560.0, "Page background · 1438×810"],
	}
	for base in grids:
		await _compare(out, vs, base, grids[base][0], grids[base][1], grids[base][2])
	await _library_view(out, vs)
	await _small_list(out, vs)
	for v in vs:
		await _board(out, v)


func _img(dir: String, base: String) -> Image:
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(base + "_") and f.ends_with(".png"):
			return Image.load_from_file(dir + "/" + f)
	return null


func _fit(img: Image, w: float) -> ImageTexture:
	var c := img.duplicate() as Image
	var h := int(round(w * img.get_height() / img.get_width()))
	c.resize(int(w), h, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(c)


func _fit_h(img: Image, h: float) -> ImageTexture:
	var c := img.duplicate() as Image
	var w := int(round(h * img.get_width() / img.get_height()))
	c.resize(w, int(h), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(c)


func _checker(c: CanvasItem, r: Rect2) -> void:
	c.draw_rect(r, Color("#2b3038"))
	var s := 16.0
	var y := r.position.y
	var row := 0
	while y < r.end.y:
		var x := r.position.x + (s if row % 2 == 1 else 0.0)
		while x < r.end.x:
			c.draw_rect(Rect2(x, y, minf(s, r.end.x - x), minf(s, r.end.y - y)), Color("#323843"))
			x += s * 2.0
		y += s
		row += 1


func _label(c: CanvasItem, v: Dictionary, x: float, y: float, w: float) -> void:
	var f := L.font("Inter-SemiBold")
	var f2 := L.font("Inter-Regular")
	L.text(c, f, "%s  %s" % [v.id, v.title], Vector2(x, y), 17, Color("#ececec"))
	var tw := L.text_w(f, "%s  %s" % [v.id, v.title], 17)
	if tw + 180 < w:
		L.text(c, f2, "· " + v.ref, Vector2(x + tw + 10, y), 15, Color("#8a8a8a"))


func _title(c: CanvasItem, t: String, w: float) -> void:
	L.text(c, L.font("Inter-Bold"), t, Vector2(32, 52), 28, Color("#ececec"))
	L.text(c, L.font("Inter-Regular"), "Godot To Steam · %d options" % _count, Vector2(w - 300, 50), 16, Color("#8a8a8a"))


func _compare(out: String, vs: Array, base: String, cols: int, cell_w: float, title: String) -> void:
	var items: Array = []
	var cell_h := 0.0
	for v in vs:
		var img := _img(v.dir, base)
		if img == null:
			continue
		var tex := _fit(img, cell_w)
		cell_h = maxf(cell_h, tex.get_height())
		items.append([v, tex])
	if items.is_empty():
		return
	var pad := 32.0
	var label_h := 34.0
	var rows := int(ceil(items.size() / float(cols)))
	var size := Vector2(pad + cols * (cell_w + pad), 90 + rows * (cell_h + label_h + pad))
	var is_logo := base == "library_logo"
	var is_hero := base == "library_hero"
	if is_logo:
		cell_h = cell_w * 0.5625
		size.y = 90 + rows * (cell_h + label_h + pad)
	await _render(out + "/compare_%s.png" % base, size, func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2.ZERO, size), SHEET_BG)
		_title(c, title, size.x)
		for i in items.size():
			var v: Dictionary = items[i][0]
			var tex: Texture2D = items[i][1]
			var x := pad + (i % cols) * (cell_w + pad)
			var y := 90 + int(i / float(cols)) * (cell_h + label_h + pad)
			_label(c, v, x, y + 18, cell_w)
			var r := Rect2(x, y + label_h, cell_w, tex.get_height())
			if is_logo:
				var box := Rect2(x, y + label_h, cell_w, cell_h)
				_checker(c, box)
				var tw := minf(cell_w * 0.86, tex.get_width())
				var th := tw * tex.get_height() / tex.get_width()
				if th > cell_h * 0.86:
					th = cell_h * 0.86
					tw = th * tex.get_width() / tex.get_height()
				r = Rect2(box.get_center() - Vector2(tw, th) * 0.5, Vector2(tw, th))
			c.draw_texture_rect(tex, r, false)
			if is_hero:
				var sa := Vector2(860, 380) * (cell_w / 3840.0)
				var sr := Rect2(r.get_center() - sa * 0.5, sa)
				var dash := Color(1, 1, 1, 0.55)
				L.dashed_line(c, sr.position, Vector2(sr.end.x, sr.position.y), dash, 1.0, 5, 4)
				L.dashed_line(c, Vector2(sr.end.x, sr.position.y), sr.end, dash, 1.0, 5, 4)
				L.dashed_line(c, sr.end, Vector2(sr.position.x, sr.end.y), dash, 1.0, 5, 4)
				L.dashed_line(c, Vector2(sr.position.x, sr.end.y), sr.position, dash, 1.0, 5, 4)
	)


## Hero with the logo on top, roughly as the Steam library detail page shows it.
func _library_view(out: String, vs: Array) -> void:
	var cell_w := 800.0
	var cell_h := cell_w * 1240.0 / 3840.0
	var pad := 32.0
	var items: Array = []
	for v in vs:
		var hero := _img(v.dir, "library_hero")
		var logo := _img(v.dir, "library_logo")
		if hero == null or logo == null:
			continue
		var lw := cell_w * 0.36
		var logo_tex := _fit(logo, lw) if logo.get_width() / float(logo.get_height()) > 1.6 else _fit_h(logo, cell_h * 0.52)
		items.append([v, _fit(hero, cell_w), logo_tex])
	if items.is_empty():
		return
	var rows := int(ceil(items.size() / 2.0))
	var size := Vector2(pad + 2 * (cell_w + pad), 90 + rows * (cell_h + 34 + pad))
	await _render(out + "/compare_library_view.png", size, func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2.ZERO, size), SHEET_BG)
		_title(c, "Library page · hero + logo (bottom-left)", size.x)
		for i in items.size():
			var x := pad + (i % 2) * (cell_w + pad)
			var y := 90 + int(i / 2.0) * (cell_h + 34 + pad)
			_label(c, items[i][0], x, y + 18, cell_w)
			var r := Rect2(x, y + 34, cell_w, cell_h)
			c.draw_texture_rect(items[i][1], r, false)
			var lt: Texture2D = items[i][2]
			var lr := Rect2(Vector2(r.position.x + cell_w * 0.05, r.end.y - cell_h * 0.1 - lt.get_height()), lt.get_size())
			c.draw_texture_rect(lt, lr, false)
	)


## Small capsules at the sizes Steam lists them (462, 231 and 120 wide).
func _small_list(out: String, vs: Array) -> void:
	var items: Array = []
	for v in vs:
		var img := _img(v.dir, "small_capsule")
		if img == null:
			continue
		items.append([v, _fit(img, 231), _fit(img, 120), _fit(img, 184)])
	if items.is_empty():
		return
	var row_h := 104.0
	var size := Vector2(1100, 100 + items.size() * row_h)
	await _render(out + "/compare_small_in_lists.png", size, func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2.ZERO, size), STEAM_BG)
		L.text(c, L.font("Inter-Bold"), "Small capsule in Steam lists · 231×87 · 184×69 · 120×45", Vector2(32, 52), 26, Color("#ececec"))
		var f := L.font("Inter-Regular")
		for i in items.size():
			var y := 90 + i * row_h
			c.draw_rect(Rect2(24, y, size.x - 48, row_h - 10), Color("#16202d"))
			c.draw_texture_rect(items[i][1], Rect2(Vector2(34, y + 3), items[i][1].get_size()), false)
			c.draw_texture_rect(items[i][3], Rect2(Vector2(290, y + 12), items[i][3].get_size()), false)
			c.draw_texture_rect(items[i][2], Rect2(Vector2(500, y + 24), items[i][2].get_size()), false)
			L.text(c, f, "Godot To Steam", Vector2(640, y + 40), 17, Color("#c7d5e0"))
			L.text(c, f, "%s  %s" % [items[i][0].id, items[i][0].title], Vector2(640, y + 66), 14, Color("#8f98a0"))
			L.text(c, f, "$9.99", Vector2(size.x - 110, y + 52), 16, Color("#beee11"))
	)


## One variant, every size, on one board.
func _board(out: String, v: Dictionary) -> void:
	var names := ["main_capsule", "header_capsule", "small_capsule", "library_capsule", "vertical_capsule", "library_hero", "library_logo", "page_background", "library_header"]
	var im := {}
	for n in names:
		var img := _img(v.dir, n)
		if img:
			im[n] = img
	if im.is_empty():
		return
	var W := 1600.0
	var t := {}
	if im.has("main_capsule"): t["main"] = _fit(im["main_capsule"], 760)
	if im.has("header_capsule"): t["header"] = _fit(im["header_capsule"], 760)
	if im.has("library_capsule"): t["lib"] = _fit(im["library_capsule"], 300)
	if im.has("vertical_capsule"): t["vert"] = _fit_h(im["vertical_capsule"], 450)
	if im.has("small_capsule"): t["small"] = _fit(im["small_capsule"], 462)
	if im.has("small_capsule"): t["small2"] = _fit(im["small_capsule"], 231)
	if im.has("small_capsule"): t["small3"] = _fit(im["small_capsule"], 120)
	if im.has("library_hero"): t["hero"] = _fit(im["library_hero"], W - 80)
	if im.has("library_logo"):
		var lg: Image = im["library_logo"]
		t["logo"] = _fit(lg, 540) if lg.get_width() / float(lg.get_height()) > 1.6 else _fit_h(lg, 300)
		t["logo_hero"] = _fit(lg, (W - 80) * 0.36) if lg.get_width() / float(lg.get_height()) > 1.6 else _fit_h(lg, (W - 80) * 0.323 * 0.52)
	if im.has("page_background"): t["page"] = _fit(im["page_background"], 740)
	var size := Vector2(W, 2010)
	await _render(out + "/variant_%s.png" % v.id, size, func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2.ZERO, size), SHEET_BG)
		L.text(c, L.font("Inter-Bold"), "%s  %s" % [v.id, v.title], Vector2(40, 56), 30, Color("#ececec"))
		L.text(c, L.font("Inter-Regular"), "inspired by " + v.ref, Vector2(40 + L.text_w(L.font("Inter-Bold"), "%s  %s" % [v.id, v.title], 30) + 16, 55), 17, Color("#8a8a8a"))
		var f := L.font("Inter-Regular")
		var cap := func(label: String, x: float, y: float) -> void:
			L.text(c, f, label, Vector2(x, y), 14, Color("#8a8a8a"))
		var y := 96.0
		if t.has("main"):
			cap.call("Main capsule", 40, y)
			c.draw_texture_rect(t["main"], Rect2(Vector2(40, y + 10), t["main"].get_size()), false)
		if t.has("lib"):
			cap.call("Library capsule", 830, y)
			c.draw_texture_rect(t["lib"], Rect2(Vector2(830, y + 10), t["lib"].get_size()), false)
		if t.has("vert"):
			cap.call("Vertical capsule", 1150, y)
			c.draw_texture_rect(t["vert"], Rect2(Vector2(1150, y + 10), t["vert"].get_size()), false)
		y = 96.0 + 10 + 436 + 36
		if t.has("header"):
			cap.call("Header capsule", 40, y)
			c.draw_texture_rect(t["header"], Rect2(Vector2(40, y + 10), t["header"].get_size()), false)
		var sy := 96.0 + 10 + 450 + 36
		if t.has("small"):
			cap.call("Small capsule (actual size and half)", 830, sy)
			c.draw_texture_rect(t["small"], Rect2(Vector2(830, sy + 10), t["small"].get_size()), false)
			c.draw_texture_rect(t["small2"], Rect2(Vector2(1310, sy + 10), t["small2"].get_size()), false)
			c.draw_texture_rect(t["small3"], Rect2(Vector2(1310, sy + 110), t["small3"].get_size()), false)
		y = y + 10 + 356 + 40
		if t.has("hero"):
			cap.call("Library hero + logo (as the Steam library shows it)", 40, y)
			var hr := Rect2(Vector2(40, y + 10), t["hero"].get_size())
			c.draw_texture_rect(t["hero"], hr, false)
			if t.has("logo_hero"):
				var lt: Texture2D = t["logo_hero"]
				c.draw_texture_rect(lt, Rect2(Vector2(hr.position.x + hr.size.x * 0.05, hr.end.y - hr.size.y * 0.1 - lt.get_height()), lt.get_size()), false)
			y = hr.end.y + 40
		if t.has("page"):
			cap.call("Page background", 40, y)
			c.draw_texture_rect(t["page"], Rect2(Vector2(40, y + 10), t["page"].get_size()), false)
		if t.has("logo"):
			cap.call("Library logo (transparent)", 820, y)
			var box := Rect2(820, y + 10, 740, 416)
			_checker(c, box)
			var lt: Texture2D = t["logo"]
			c.draw_texture_rect(lt, Rect2(box.get_center() - lt.get_size() * 0.5, lt.get_size()), false)
	)


func _render(path: String, size: Vector2, fn: Callable) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(size)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_host.add_child(vp)
	var layer := DrawLayer.new()
	layer.size = size
	layer.fn = fn
	vp.add_child(layer)
	for i in 3:
		await _host._next_draw()
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(path)
	print("[steam_art] sheet ", path)
	vp.queue_free()
