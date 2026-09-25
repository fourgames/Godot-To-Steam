extends "res://marketing/steam_art/patterns/patterns_base.gd"
## P05 Equalizer: rounded bars rising to the right, like the app's progress bars stacked into a skyline.


func _init() -> void:
	id = "P05"
	title = "Equalizer"
	inspired_by = "rising rounded bars"


func waves(c: CanvasItem, s: Vector2, spread: float, lift: float = 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 605
	var base_h := [0.21, 0.15, 0.1, 0.06]
	var aspect := s.x / s.y
	for li in 4:
		var cols := int(clampf(aspect * 8.0, 6.0, 40.0)) + li * 3
		var w := s.x / cols
		var off := w * (0.5 if li % 2 == 1 else 0.0)
		for k in cols + 1:
			var x := k * w - off
			var t := clampf((x + w * 0.5) / s.x, 0.0, 1.0)
			var h: float = base_h[li] + lift * (1.0 - li * 0.15) + 0.14 * spread * t + rng.randf_range(-0.035, 0.035)
			if _mode == "hero":
				h *= lerpf(0.12, 1.0, smoothstep(0.38, 0.58, t))
			var top := s.y * (1.0 - h)
			var bw := w * 0.78
			var body := Rect2(x + (w - bw) * 0.5, top, bw, s.y - top + bw)
			var crest: Color = LAYERS[li][0]
			var far: Color = LAYERS[li][1]
			L.rrect(c, body, bw * 0.28, far.lerp(crest, 0.45))
			L.rrect(c, Rect2(body.position, Vector2(bw, minf(bw * 0.55, body.size.y))), bw * 0.28, crest)
