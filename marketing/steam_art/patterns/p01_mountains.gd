extends "res://marketing/steam_art/patterns/patterns_base.gd"
## P01 Mountains: jagged layered ridges (midpoint displacement) instead of sine waves.


func _init() -> void:
	id = "P01"
	title = "Mountains"
	inspired_by = "jagged ridge layers"


func _ridge(rng: RandomNumberGenerator, rough: float) -> Array:
	var ys: Array = [0.0, 0.0]
	var disp := rough
	for it in 4:
		var nys: Array = []
		for i in ys.size() - 1:
			nys.append(ys[i])
			nys.append((ys[i] + ys[i + 1]) * 0.5 + rng.randf_range(-disp, disp))
		nys.append(ys[ys.size() - 1])
		ys = nys
		disp *= 0.5
	return ys


func waves(c: CanvasItem, s: Vector2, spread: float, lift: float = 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 601
	var tops := [[0.14, 0.07, TOP_DEEP], [0.05, 0.05, TOP_MID]]
	for tp in tops:
		var ys := _ridge(rng, tp[1])
		var edge := PackedVector2Array()
		for i in ys.size():
			var t := float(i) / (ys.size() - 1)
			edge.append(Vector2(s.x * t, s.y * (tp[0] - lift * 0.3 + absf(ys[i]) - 0.2 * spread * (t - 0.5))))
		fill_to(c, s, edge, 0.0, tp[2][0], tp[2][1])
		edge_line(c, s, edge, 0.12)
	var bases := [0.66, 0.76, 0.86, 0.95]
	var rough := [0.28, 0.22, 0.17, 0.11]
	for li in 4:
		var ys := _ridge(rng, rough[li])
		var edge := PackedVector2Array()
		for i in ys.size():
			var t := float(i) / (ys.size() - 1)
			var y: float = bases[li] - lift * (1.0 - li * 0.13) - absf(ys[i]) - 0.22 * spread * (t - 0.5)
			if _mode == "hero":
				y = lerpf(y, maxf(y, 0.86 + (bases[li] - 0.66) * 0.5), 1.0 - smoothstep(0.2, 0.62, t))
			edge.append(Vector2(s.x * t, s.y * y))
		fill_to(c, s, edge, s.y, LAYERS[li][0], LAYERS[li][1])
		edge_line(c, s, edge, EDGE_A[li])
