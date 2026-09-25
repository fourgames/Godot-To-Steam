extends "res://marketing/steam_art/waves/waves_base.gd"
## 6.01 Refined: the original Depot Waves with a soft cyan halo behind the icon.


func _init() -> void:
	id = "6.01"
	title = "Refined"
	inspired_by = "original 06 + icon glow"
	cfg.merge({"icon_glow": 0.28}, true)
