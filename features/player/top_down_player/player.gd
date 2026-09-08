extends CharacterBody3D


signal step

func _emit_steps_with_anim():
	emit_signal("step")

@export var SPEED := 4.0
@export var DEADZONE = 0.0

const BASE_SPEED := 4.0

var current_anim_speed := 1.0


func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var input_strength := input_direction.length()
	
	if velocity.length() < 0.1:
		current_anim_speed = lerpf(current_anim_speed, 1.0, 10 * _delta)
	else:
		var target_speed = (SPEED / 4.0)
		current_anim_speed = lerpf(current_anim_speed, target_speed, 10 * _delta)
	
	if input_strength > DEADZONE:
		input_direction = input_direction.normalized() 
		var speed_multiplier := input_strength
		var movement_direction := (transform.basis * Vector3(input_direction.x, 0, input_direction.y)).rotated(Vector3.UP, deg_to_rad(45)).normalized()
		
		velocity.x = movement_direction.x * SPEED * speed_multiplier
		velocity.z = movement_direction.z * SPEED * speed_multiplier
		
		var look_target = $MeshInstance3D.global_position - movement_direction
		look_target.y = $MeshInstance3D.global_position.y 
		$MeshInstance3D.look_at(look_target, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	move_and_slide()
