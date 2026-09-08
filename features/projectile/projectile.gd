extends Node3D


var speed := 10
var despawn_time = 10


func _ready() -> void:
	%Timer.wait_time = despawn_time


func _process(delta: float) -> void:
	position -= transform.basis.z.normalized() * speed * delta 
	if %RayCast3D.is_colliding():
		queue_free()


func _on_timer_timeout() -> void:
	queue_free()

# TODO seams it pierces eveyrthing fix this should remove on contact
func _on_hitbox_component_area_entered() -> void:
	queue_free()
