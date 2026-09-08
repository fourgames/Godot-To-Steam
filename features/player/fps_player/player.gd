extends CharacterBody3D


var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.8
var sensitivity
var mouse_sensitivity: float
var controller_sensitivity: float

#bob variables
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob = 0.0

#fov variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 9.8

@onready var head = %Head
@onready var camera = %Camera3D


# TODO add polish like jump buffer and cayote time
func _ready() -> void:
	SignalManager.sensitivity_changed.connect(sensitivity_changed_update_values)
	sensitivity_changed_update_values()
	# Force the physics state to be still
	velocity = Vector3.ZERO
	set_physics_process(false) # Disable physics entirely
	
	# Wait for the world to load/settle
	await get_tree().create_timer(0.1).timeout 
	
	set_physics_process(true) # Re-enable physics


func sensitivity_changed_update_values():
	sensitivity = DataManager.payload.input.sensitivity
	mouse_sensitivity = sensitivity * 0.00005
	controller_sensitivity = sensitivity * 0.05


func _unhandled_input(event):
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))


func _physics_process(delta):
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	var look_dir = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	
	if look_dir.length() > 0:
		
		var current_sens = controller_sensitivity
		if %ShapeCast3D.is_colliding():
			var target = %ShapeCast3D.get_collider(0)
			var target_center = target.global_position + Vector3(0, 1.2, 0)
			
			# 1. Get the direction to target
			var dir_to_target = (target_center - camera.global_position).normalized()
			
			# 2. Calculate the "Goal" horizontal and vertical angles
			var yaw_goal = atan2(-dir_to_target.x, -dir_to_target.z)
			var pitch_goal = asin(dir_to_target.y)
			
			# 3. Strength based on stick force (your existing logic)
			var stick_force = look_dir.length()
			var magnetism_strength = lerp(5.0, 2.0, stick_force)
			var weight = magnetism_strength * delta
			
			# 4. Smoothly rotate the Head (Y) and Camera (X) separately
			# This prevents the 'tilt' or 'slushiness'
			head.global_rotation.y = lerp_angle(head.global_rotation.y, yaw_goal, weight)
			camera.rotation.x = lerp_angle(camera.rotation.x, pitch_goal, weight)
			
			# Keep camera local Y at 0 because the Head node handles horizontal rotation
			camera.rotation.y = 0
			camera.rotation.z = 0
			
			if stick_force < 0.8:
				current_sens *= 0.7
		
		head.rotate_y(-look_dir.x * current_sens * delta)
		camera.rotate_x(-look_dir.y * current_sens * delta)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))
		
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Handle Sprint.
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED
	
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	#var direction = (head.transform.basis * transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var direction = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
	
	# Head bob
	#t_bob += delta * velocity.length() * float(is_on_floor())
	#camera.transform.origin = _headbob(t_bob)
	if is_on_floor() and velocity.length() > 0.1:
		t_bob += delta * velocity.length()
		camera.transform.origin = _headbob(t_bob)
	else:
		t_bob = lerp(t_bob, 0.0, delta * 2.0)
		camera.transform.origin = camera.transform.origin.lerp(Vector3.ZERO, delta * 2.0)
	
	## FOV
	#var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	#var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	#camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	#
	#move_and_slide()
	# FOV
	# We use 0.0 so that standing still doesn't create a "zoom" offset
	var velocity_clamped = clamp(velocity.length(), 0.0, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	
	# Only apply the lerp if the player is playing
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	move_and_slide()


func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
