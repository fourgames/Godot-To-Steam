@icon("uid://woodippmsfcd")
extends Area3D


var target_interactable = null


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("Loot"):
		print("Interact enter")
		target_interactable = area


func _on_area_exited(area: Area3D) -> void:
	if area.is_in_group("Loot"):
		print("Interact exit")
		target_interactable = null


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and target_interactable:
		target_interactable.interact()
