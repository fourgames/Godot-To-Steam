extends "res://marketing/steam_art/waves/waves_base.gd"
## 6.09 Glass Card: the lockup sits on a frosted glass card over the waves.


func _init() -> void:
	id = "6.09"
	title = "Glass Card"
	inspired_by = "frosted card lockup"
	cfg.merge({"card": true}, true)
