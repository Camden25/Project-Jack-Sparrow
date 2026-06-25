extends HitscanWeaponBase
class_name Flintlock

const HIPFIRE_SPREAD: float = 0.04

func _get_fire_direction() -> Vector3:
	var camera = owner_player.get_node("Head/Camera3D")
	var base_direction = -camera.global_basis.z
	var spread_x = randf_range(-HIPFIRE_SPREAD, HIPFIRE_SPREAD)
	var spread_y = randf_range(-HIPFIRE_SPREAD, HIPFIRE_SPREAD)
	return (base_direction + Vector3(spread_x, spread_y, 0)).normalized()
