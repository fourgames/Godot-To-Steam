@icon("uid://dde1sa4xfshfr")
extends Area3D
class_name HitboxComponent


@export var damage : int = -10 
@onready var tick_timer: Timer = $TickTimer


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if collision_layer != 0:
		warnings.append("A hitbox should not be on a layer")

	if collision_mask == 0:
		warnings.append("A hitbox should be on a mask")

	return warnings


func _ready() -> void:
	if _get_configuration_warnings().size() > 0:
		for error in _get_configuration_warnings():
			push_warning("Hitbox Error at ", get_path(), ": ", error)


func _on_area_entered(area: Area3D) -> void:
	if area is HurtboxComponent:
		area.apply_health_change(damage)
		if tick_timer.is_stopped():
			tick_timer.start()


func _on_tick_timer_timeout() -> void:
	var overlapping_areas = get_overlapping_areas()
	
	if overlapping_areas.is_empty():
		tick_timer.stop()
		return
	
	for area in overlapping_areas:
		if area is HurtboxComponent:
			area.apply_health_change(damage)
