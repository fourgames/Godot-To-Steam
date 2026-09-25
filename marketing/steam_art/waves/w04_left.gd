extends "res://marketing/steam_art/waves/waves_base.gd"
## 6.04 Left Lockup: icon and name on the left, the waves rising to the right.


func _init() -> void:
	id = "6.04"
	title = "Left Lockup"
	inspired_by = "icon + name left, waves right"
	cfg.merge({"layout": "left", "icon_glow": 0.2}, true)
