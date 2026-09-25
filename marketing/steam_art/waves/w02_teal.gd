extends "res://marketing/steam_art/waves/waves_base.gd"
## 6.02 Teal Tide: the same waves in teal and mint over deep sea blue.


func _init() -> void:
	id = "6.02"
	title = "Teal Tide"
	inspired_by = "teal / mint palette"
	cfg.merge({
		"bg_a": Color("#06202a"), "bg_b": Color("#03101a"), "glow": Color("#2ec4b6", 0.14),
		"top": [
			[0.2, 0.07, 0.8, 1.2, -0.5, Color("#0e5a6e"), Color("#082836"), 0.1],
			[0.08, 0.05, 1.1, 2.4, -0.45, Color("#1b6f86"), Color("#0c3a4a"), 0.18],
		],
		"bottom": [
			[0.72, 0.06, 0.9, 0.4, -0.55, Color("#0f5a6e", 0.95), Color("#062633"), 0.12],
			[0.8, 0.055, 1.2, 2.0, -0.5, Color("#1a8a9a"), Color("#0b4652"), 0.22],
			[0.9, 0.05, 1.5, 3.6, -0.42, Color("#2ec4b6"), Color("#127a78"), 0.35],
			[0.98, 0.04, 1.8, 5.1, -0.3, Color("#7ee0c8"), Color("#2a9d8f"), 0.4],
		],
		"icon_glow": 0.18,
	}, true)
