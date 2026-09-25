extends "res://marketing/steam_art/waves/waves_base.gd"
## 6.08 Progress Crest: the app's green progress cells ride the front wave to a check.


func _init() -> void:
	id = "6.08"
	title = "Progress Crest"
	inspired_by = "app progress bar on the crest"
	cfg.merge({"crest": true, "icon_glow": 0.18}, true)
