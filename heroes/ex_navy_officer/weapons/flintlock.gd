extends HitscanWeaponBase
class_name Flintlock

@export var spread: float = 0.04

func _get_fire_direction() -> Vector3:
	var camera: Camera3D = owner_player.get_node("Head/Camera3D")

	var forward = -camera.global_basis.z
	var right = camera.global_basis.x
	var up = camera.global_basis.y

	var spread_x = randf_range(-spread, spread)
	var spread_y = randf_range(-spread, spread)

	return (forward + right * spread_x + up * spread_y).normalized()
