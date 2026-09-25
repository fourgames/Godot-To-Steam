extends "res://marketing/steam_art/waves/waves_base.gd"
## 6.06 Floating Clover: the bare glossy clover with a halo instead of the icon tile.


func _init() -> void:
	id = "6.06"
	title = "Floating Clover"
	inspired_by = "bare clover, glow halo"
	cfg.merge({"icon": "clover", "icon_glow": 0.4}, true)
