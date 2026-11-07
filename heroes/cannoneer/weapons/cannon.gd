extends ProjectileWeaponBase
class_name Cannon

func _get_fire_direction() -> Vector3:
	var camera := owner_player.get_node_or_null("Head/Camera3D") as Camera3D
	if not camera:
		push_error("ProjectileWeaponBase could not find the owner's camera")
		return Vector3.ZERO
	
	var forward = -camera.global_basis.z
	var right = camera.global_basis.x
	var up = camera.global_basis.y
	
	var up_amount: float = 0.2
	
	return (forward + right * 0 + up * up_amount).normalized()
