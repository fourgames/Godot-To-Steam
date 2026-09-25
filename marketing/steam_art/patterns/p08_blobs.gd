extends "res://marketing/steam_art/patterns/patterns_base.gd"
## P08 Liquid Blobs: soft organic blobs pooling in the corners with lit rims.


func _init() -> void:
	id = "P08"
	title = "Liquid Blobs"
	inspired_by = "organic blobs"


func waves(c: CanvasItem, s: Vector2, spread: float, lift: float = 0.0) -> void:
	var u := sqrt(s.x * s.y)
	var blobs := [
		[Vector2(0.14, -0.1), 0.42, TOP_DEEP, 0.7],
		[Vector2(0.02, 0.06), 0.25, TOP_MID, 1.9],
		[Vector2(0.95, 1.08), 0.5, BACK, 0.3],
		[Vector2(1.03, 0.96), 0.34, MID, 1.1],
		[Vector2(0.8, 1.12), 0.25, BRIGHT, 2.2],
		[Vector2(0.66, 1.2), 0.2, FRONT, 3.0],
	]
	for b in blobs:
		var uv: Vector2 = b[0]
		if _mode == "hero" and uv.x < 0.45 and uv.y > 0.5:
			continue
		var ctr := Vector2(s.x * uv.x, s.y * (uv.y - lift * (0.5 if uv.y > 0.5 else 0.2)))
		var r: float = u * b[1]
		var layer: Array = b[2]
		L.glow(c, ctr, r * 1.25, Color(layer[0], 0.12), 20)
		var pts := blob(ctr, r, b[3], 1.1)
		fan(c, pts, ctr + Vector2(0, r * 0.25), layer[1].lerp(layer[0], 0.25), layer[0])
		var closed := pts.duplicate()
		closed.append(pts[0])
		c.draw_polyline(closed, Color(1, 1, 1, 0.16), maxf(1.0, s.y * 0.004), true)
