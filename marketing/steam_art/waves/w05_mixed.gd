extends "res://marketing/steam_art/waves/waves_base.gd"
## 6.05 Mixed Case: "Godot To Steam" in heavy mixed case instead of spaced caps.


func _init() -> void:
	id = "6.05"
	title = "Mixed Case"
	inspired_by = "heavy mixed-case name"
	cfg.merge({"case": "mixed", "icon_glow": 0.2}, true)
