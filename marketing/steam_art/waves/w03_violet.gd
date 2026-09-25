extends "res://marketing/steam_art/waves/waves_base.gd"
## 6.03 Violet Drift: closest to DSX, with magenta and violet rising under Godot blue.


func _init() -> void:
	id = "6.03"
	title = "Violet Drift"
	inspired_by = "DSX magenta / violet"
	cfg.merge({
		"bg_a": Color("#120c33"), "bg_b": Color("#080620"), "glow": Color("#7c4dff", 0.18),
		"top": [
			[0.2, 0.07, 0.8, 1.2, -0.5, Color("#3a2a8c"), Color("#1a1245"), 0.1],
			[0.08, 0.05, 1.1, 2.4, -0.45, Color("#4b35a8"), Color("#221a5c"), 0.18],
		],
		"bottom": [
			[0.72, 0.06, 0.9, 0.4, -0.55, Color("#4a2a9c", 0.95), Color("#150b40"), 0.12],
			[0.8, 0.055, 1.2, 2.0, -0.5, Color("#7a3fd1"), Color("#2a1470"), 0.22],
			[0.9, 0.05, 1.5, 3.6, -0.42, Color("#b44fd6"), Color("#5a2090"), 0.35],
			[0.98, 0.04, 1.8, 5.1, -0.3, Color("#b04fc0", 0.8), Color("#6a2a80", 0.8), 0.3],
		],
		"icon_glow": 0.2,
	}, true)
