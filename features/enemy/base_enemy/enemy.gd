extends CharacterBody3D


@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@export var speed = 2.0 

var players = null


func _ready() -> void:
	players = get_tree().get_nodes_in_group("Player")
	_on_agent_timer_timeout()


func _physics_process(delta: float) -> void:
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * speed
	
	velocity = velocity.move_toward(new_velocity, 0.25)
	move_and_slide()
	
	rotation.y = lerp_angle(rotation.y, atan2(global_transform.origin.x - next_location.x, global_transform.origin.z - next_location.z), delta * 2)


func update_target_location(target_location):
	nav_agent.set_target_position(target_location)
	await get_tree().create_timer(10).timeout


func _on_agent_timer_timeout() -> void:
	%AgentTimer.wait_time = randf_range(0.3, 0.5) 
		
	nav_agent.set_target_position(players[0].global_transform.origin)
