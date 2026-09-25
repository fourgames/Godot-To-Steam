extends "res://marketing/steam_art/waves/waves_base.gd"
## 6.07 Mono Blue: every wave a shade of the app's Godot blue, no edge lines, calm.


func _init() -> void:
	id = "6.07"
	title = "Mono Blue"
	inspired_by = "single-hue Godot blue"
	cfg.merge({
		"bg_a": Color("#0f1f38"), "bg_b": Color("#0b1a33"), "glow": Color("#478cbf", 0.14),
		"top": [
			[0.2, 0.07, 0.8, 1.2, -0.5, Color("#1d3a5c"), Color("#11243a"), 0.0],
			[0.08, 0.05, 1.1, 2.4, -0.45, Color("#27507d"), Color("#15304e"), 0.0],
		],
		"bottom": [
			[0.72, 0.06, 0.9, 0.4, -0.55, Color("#23476f"), Color("#0f2238"), 0.0],
			[0.8, 0.055, 1.2, 2.0, -0.5, Color("#2f6292"), Color("#16365a"), 0.0],
			[0.9, 0.05, 1.5, 3.6, -0.42, Color("#3f80c0"), Color("#1f4a80"), 0.0],
			[0.98, 0.04, 1.8, 5.1, -0.3, Color("#4f9be0"), Color("#2a64a0"), 0.0],
		],
	}, true)
