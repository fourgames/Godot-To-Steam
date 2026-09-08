@icon("uid://deb6kvmuw5vgc")
extends Node3D
class_name NumbersComponent


const COLOR_HEAL = Color(0.15, 0.85, 0.15) 
const COLOR_LOW  = Color(1, 1, 1)
const COLOR_MID  = Color(1, 0.9, 0.2)
const COLOR_HIGH = Color(1, 0.6, 0.1)
const COLOR_CRIT = Color(0.9, 0.1, 0.1)


func setup(value):
	var amount = abs(int(value))
	var target_color: Color
	
	if value > 0:
		target_color = COLOR_HEAL
	elif value >= -122:
		target_color = COLOR_LOW
	elif value >= -194:
		target_color = COLOR_MID
	elif value >= -266:
		target_color = COLOR_HIGH
	else:
		target_color = COLOR_CRIT

	%RichTextLabel.text = "[color=#%s]%s[/color]" % [target_color.to_html(false), amount]


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "rise_and_fade":
		queue_free()
