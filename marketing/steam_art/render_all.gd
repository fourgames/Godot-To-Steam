extends Node
## Renders every Steam art variant at every Steam asset size to
## ~/Movies/GUI/Steam Art/, then the comparison sheets, then quits.
##
## Run: project_run(mode="custom", scene="res://marketing/steam_art/render_all.tscn")
## Optional res://marketing/steam_art/job.json picks a subset:
##   {"variants": [1, 4], "kinds": ["header", "small"], "sheets": false}
## Shortlist sheets only: {"kinds": [], "sheet_variants": [1, 2], "sheet_dir": "_compare_shortlist"}
## "set": "waves" renders the ten Depot Waves takes (waves/) into their own folder;
## "set": "patterns" renders the ten background-pattern studies (patterns/).

const Sheets := preload("res://marketing/steam_art/sheets.gd")

## Supersampling factor: art is drawn at SS x the target size, then
## downscaled with Lanczos (MSAA 2D is unreliable in the Compatibility renderer).
const SS := 2
const OUT_DIR := "/Movies/GUI/Steam Art"
const JOB := "res://marketing/steam_art/job.json"

const KINDS := {
	"header": [Vector2i(920, 430), "header_capsule"],
	"small": [Vector2i(462, 174), "small_capsule"],
	"main": [Vector2i(1232, 706), "main_capsule"],
	"vertical": [Vector2i(748, 896), "vertical_capsule"],
	"library_capsule": [Vector2i(600, 900), "library_capsule"],
	"library_header": [Vector2i(920, 430), "library_header"],
	"library_hero": [Vector2i(3840, 1240), "library_hero"],
	"library_logo": [Vector2i(1280, 720), "library_logo"],
	"page_background": [Vector2i(1438, 810), "page_background"],
}

const VARIANTS := [
	"res://marketing/steam_art/variants/v01_charcoal.gd",
	"res://marketing/steam_art/variants/v02_console.gd",
	"res://marketing/steam_art/variants/v03_window.gd",
	"res://marketing/steam_art/variants/v04_split.gd",
	"res://marketing/steam_art/variants/v05_ripple.gd",
	"res://marketing/steam_art/variants/v06_waves.gd",
	"res://marketing/steam_art/variants/v07_facets.gd",
	"res://marketing/steam_art/variants/v08_starfield.gd",
	"res://marketing/steam_art/variants/v09_pixel.gd",
	"res://marketing/steam_art/variants/v10_launch.gd",
]

## Ten takes on variant 06 Depot Waves.
const WAVES := [
	"res://marketing/steam_art/waves/w01_refined.gd",
	"res://marketing/steam_art/waves/w02_teal.gd",
	"res://marketing/steam_art/waves/w03_violet.gd",
	"res://marketing/steam_art/waves/w04_left.gd",
	"res://marketing/steam_art/waves/w05_mixed.gd",
	"res://marketing/steam_art/waves/w06_clover.gd",
	"res://marketing/steam_art/waves/w07_mono.gd",
	"res://marketing/steam_art/waves/w08_crest.gd",
	"res://marketing/steam_art/waves/w09_glass.gd",
	"res://marketing/steam_art/waves/w10_aurora.gd",
]
const WAVES_DIR := "/06 Depot Waves - 10 takes"

## Ten background-pattern studies on 06, with the original first for reference.
const PATTERNS := [
	"res://marketing/steam_art/variants/v06_waves.gd",
	"res://marketing/steam_art/patterns/p01_mountains.gd",
	"res://marketing/steam_art/patterns/p02_bands.gd",
	"res://marketing/steam_art/patterns/p03_ribbons.gd",
	"res://marketing/steam_art/patterns/p04_arcs.gd",
	"res://marketing/steam_art/patterns/p05_equalizer.gd",
	"res://marketing/steam_art/patterns/p06_topo.gd",
	"res://marketing/steam_art/patterns/p07_swoosh.gd",
	"res://marketing/steam_art/patterns/p08_blobs.gd",
	"res://marketing/steam_art/patterns/p09_folds.gd",
	"res://marketing/steam_art/patterns/p10_halftone.gd",
]
const PATTERNS_DIR := "/06 Depot Waves - 10 patterns"

var _status: Label


func _ready() -> void:
	OS.low_processor_usage_mode = false
	get_window().always_on_top = true
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("#151515")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	_status = Label.new()
	_status.position = Vector2(40, 40)
	_status.add_theme_font_size_override("font_size", 22)
	layer.add_child(_status)
	var job := _load_job()
	var root_dir := OS.get_environment("HOME") + OUT_DIR
	var paths: Array = VARIANTS
	if job.get("set", "main") == "waves":
		paths = WAVES
		root_dir += WAVES_DIR
	elif job.get("set", "main") == "patterns":
		paths = PATTERNS
		root_dir += PATTERNS_DIR
	var variant_ids: Array = job.get("variants", range(1, paths.size() + 1))
	var kinds: Array = job.get("kinds", KINDS.keys())
	var t0 := Time.get_ticks_msec()
	var count := 0
	for vid in variant_ids:
		var path: String = paths[int(vid) - 1]
		if not ResourceLoader.exists(path):
			print("[steam_art] skip missing ", path)
			continue
		var variant = load(path).new()
		var dir := "%s/%s %s" % [root_dir, variant.id, variant.title]
		DirAccess.make_dir_recursive_absolute(dir)
		for kind in kinds:
			_status.text = "Rendering %s %s · %s" % [variant.id, variant.title, kind]
			var img := await _render(variant, kind)
			var file := "%s/%s_%dx%d.png" % [dir, KINDS[kind][1], img.get_width(), img.get_height()]
			_remove_old(dir, KINDS[kind][1])
			img.save_png(file)
			count += 1
			print("[steam_art] saved ", file)
	print("[steam_art] rendered %d images in %.1fs" % [count, (Time.get_ticks_msec() - t0) / 1000.0])
	if job.get("sheets", true):
		_status.text = "Building comparison sheets"
		# "sheet_variants" + "sheet_dir" build a shortlist comparison from
		# already-rendered variants without touching the full sheets.
		var picks: Array = []
		for vid in job.get("sheet_variants", range(1, paths.size() + 1)):
			picks.append(paths[int(vid) - 1])
		await Sheets.new().build(self, root_dir, picks, job.get("sheet_dir", "_compare"))
	print("[steam_art] done")
	get_tree().quit()


func _load_job() -> Dictionary:
	if not FileAccess.file_exists(JOB):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(JOB))
	return data if data is Dictionary else {}


func _remove_old(dir: String, base: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(base + "_") and f.ends_with(".png"):
			DirAccess.remove_absolute(dir + "/" + f)


func _render(variant, kind: String) -> Image:
	var target: Vector2i = KINDS[kind][0]
	var vp := SubViewport.new()
	vp.size = target * SS
	vp.disable_3d = true
	vp.transparent_bg = kind == "library_logo"
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var root := Control.new()
	root.size = Vector2(vp.size)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(root)
	variant.build(root, kind, Vector2(vp.size))
	for i in 3:
		await _next_draw()
	var img := vp.get_texture().get_image()
	vp.queue_free()
	img.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
	if kind == "library_logo":
		_unpremultiply(img)
		img = _crop_logo(img)
	else:
		img.convert(Image.FORMAT_RGB8)
	if kind == "page_background" and variant.page_blur > 0.0:
		var w := img.get_width()
		var h := img.get_height()
		img.resize(maxi(8, int(w / variant.page_blur)), maxi(8, int(h / variant.page_blur)), Image.INTERPOLATE_LANCZOS)
		img.resize(w, h, Image.INTERPOLATE_CUBIC)
	return img


## Waits for one drawn frame; forces a draw if macOS stopped drawing a covered window.
func _next_draw() -> void:
	var state := {"done": false}
	var cb := func() -> void: state.done = true
	RenderingServer.frame_post_draw.connect(cb, CONNECT_ONE_SHOT)
	var t0 := Time.get_ticks_msec()
	while not state.done:
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > 3000:
			print("[steam_art] frame stalled, forcing a draw")
			RenderingServer.force_draw(false)
			t0 = Time.get_ticks_msec()


## A transparent viewport stores premultiplied colour; PNG wants straight alpha.
func _unpremultiply(img: Image) -> void:
	var data := img.get_data()
	var brighter := 0
	for i in range(0, data.size(), 4):
		var a := data[i + 3]
		if a == 0 or a == 255:
			continue
		if data[i] > a + 2 or data[i + 1] > a + 2 or data[i + 2] > a + 2:
			brighter += 1
		for ch in 3:
			data[i + ch] = mini(255, int(round(data[i + ch] * 255.0 / a)))
	if brighter > 0:
		print("[steam_art] warning: %d pixels brighter than alpha, data may not be premultiplied" % brighter)
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


## Steam wants the logo 1280 wide and/or 720 tall: trim to the logo (plus a
## clear margin past the shadow), then centre it on a 1280-wide (or 720-tall)
## transparent canvas so the padding is equal on both sides.
func _crop_logo(img: Image) -> Image:
	var used := img.get_used_rect()
	if used.size.x <= 0:
		return img
	var m := 24
	var r := Rect2i(used.position - Vector2i(m, m), used.size + Vector2i(m, m) * 2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var tight := img.get_region(r)
	var out: Image
	if float(r.size.x) / img.get_width() >= float(r.size.y) / img.get_height():
		out = Image.create_empty(img.get_width(), r.size.y, false, Image.FORMAT_RGBA8)
		out.blit_rect(tight, Rect2i(Vector2i.ZERO, r.size), Vector2i((img.get_width() - r.size.x) / 2, 0))
	else:
		out = Image.create_empty(r.size.x, img.get_height(), false, Image.FORMAT_RGBA8)
		out.blit_rect(tight, Rect2i(Vector2i.ZERO, r.size), Vector2i(0, (img.get_height() - r.size.y) / 2))
	return out
