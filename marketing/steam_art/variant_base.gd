extends RefCounted
## One Steam art variant. build() is called once per asset kind with a fresh
## root Control sized to the supersampled render target (s, in pixels).
## Subclasses override capsule(), background() and mark().

const L := preload("res://marketing/steam_art/lib.gd")

var id := "00"
var title := "Untitled"
var inspired_by := ""
## Page background blur: downscale factor before scaling back up (0 = off).
var page_blur := 10.0


func build(root: Control, kind: String, s: Vector2) -> void:
	match kind:
		"library_logo":
			logo(root, s)
		"library_hero":
			background(root, s, "hero")
		"page_background":
			background(root, s, "page")
		_:
			capsule(root, kind, s)


## Background art only (no text, no logo). mode: "hero" | "page" | "capsule".
func background(_root: Control, _s: Vector2, _mode: String) -> void:
	pass


func capsule(_root: Control, _kind: String, _s: Vector2) -> void:
	pass


## Wordmark lockup spec (see lib.gd lockup()). kind lets small/tall differ.
func mark(_kind: String) -> Dictionary:
	return {}


## Library logo: the lockup on transparent with a soft drop shadow. The
## renderer crops it to the logo's bounds.
func logo(root: Control, s: Vector2) -> void:
	var spec := mark("library_logo")
	spec["shadow"] = spec.get("shadow", [0.22, 0.55])
	# Generous padding so the soft shadow never meets the canvas edge.
	var pad := s.y * 0.16
	L.add_draw(root, func(c: Control) -> void:
		L.lockup(c, Rect2(Vector2(pad, pad), s - Vector2(pad, pad) * 2.0), spec))


static func tall(s: Vector2) -> bool:
	return s.y > s.x * 1.05


## Rect helper in fractions of s.
static func fr(s: Vector2, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(s.x * x, s.y * y, s.x * w, s.y * h)
