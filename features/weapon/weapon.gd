extends Area3D
class_name WeaponComponent


var shots_per_fire: int = 1
var spread_angle : float = 5
var radius : float = 6

var projectile = preload(PathManager.projectile)
var projectile_instance


func _physics_process(delta: float) -> void:
	var enemies_in_range = get_overlapping_areas()
	
	if enemies_in_range.size() > 0:
		var return_speed = 5.0
		%RotationAnchor.rotation.x = lerp_angle(%RotationAnchor.rotation.x, 0.0, delta * return_speed)
		
		var nearest_enemy = enemies_in_range[0]
		var nearest_distance = global_position.distance_to(nearest_enemy.global_position)
		
		for enemy in enemies_in_range:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < nearest_distance:
				nearest_enemy = enemy
				nearest_distance = dist
		
		var target_position = nearest_enemy.global_position
		target_position.y += 1.0
		
		var target_transform = global_transform.looking_at(target_position, Vector3.UP)
		
		var rotation_speed = 10.0 
		
		var current_basis = global_transform.basis.orthonormalized()
		var target_basis = target_transform.basis.orthonormalized()

		global_transform.basis = current_basis.slerp(
			target_basis, 
			delta * rotation_speed
		)
		
		rotation.x = 0
	else:
			var idle_spin_speed = 2.0
			%RotationAnchor.rotation.x += idle_spin_speed * delta
			var other_spin = 0.5
			rotate_y(other_spin * delta)


func _on_fire_timer_timeout() -> void:
	if get_overlapping_areas().size() > 0:
		$ActionsAnim.play("Rifle_Fire_Anim")
		spawn_projectile(projectile, shots_per_fire, spread_angle)

func spawn_projectile(projectile_scene, shots, spread):
	var angle_step = spread / max(shots - 1, 1) if shots > 1 else spread
	
	for i in range(shots):
		projectile_instance = projectile_scene.instantiate()
		projectile_instance.position = %Marker3D.global_position
		projectile_instance.transform.basis = %Marker3D.global_transform.basis
		var angle = -spread / 2 + i * angle_step
		
		if shots == 1:
			angle += randf_range(-spread / 2, spread / 2)
		
		projectile_instance.transform.basis = projectile_instance.transform.basis.rotated(Vector3.UP, deg_to_rad(angle))
		get_parent().get_parent().add_child(projectile_instance)
