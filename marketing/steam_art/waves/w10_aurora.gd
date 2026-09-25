extends "res://marketing/steam_art/waves/waves_base.gd"
## 6.10 Aurora Lines: the waves drawn as thin glowing line strands on near-black.


func _init() -> void:
	id = "6.10"
	title = "Aurora Lines"
	inspired_by = "waves as glowing strands"
	page_blur = 16.0
	cfg.merge({
		"style": "strands",
		"bg_a": Color("#070a16"), "bg_b": Color("#03040a"), "glow": Color("#3b5bdb", 0.14),
		"top": [[0.26, 0.05, 0.8, 1.2, -0.5, Color("#3b5bdb"), Color("#1b2a6b"), 0.0]],
		"bottom": [
			[0.7, 0.06, 0.9, 0.4, -0.55, Color("#48baff"), Color("#1f3f86"), 0.0],
			[0.8, 0.055, 1.2, 2.0, -0.5, Color("#5fd6e8"), Color("#2b62b8"), 0.0],
			[0.9, 0.05, 1.5, 3.6, -0.42, Color("#86c29a"), Color("#1f7f6a"), 0.0],
		],
		"icon_glow": 0.25,
	}, true)
