extends HitscanWeaponBase
class_name Shotgun

@export var num_bullets: int = 10
@export var spread: float = 0.2

func _fire():
	for i in range(num_bullets):
		super._fire()

func _get_fire_direction() -> Vector3:
	var camera: Camera3D = owner_player.get_node("Head/Camera3D")

	var forward = -camera.global_basis.z
	var right = camera.global_basis.x
	var up = camera.global_basis.y

	var angle = randf() * TAU
	var radius = sqrt(randf()) * spread

	var offset = right * cos(angle) * radius
	offset += up * sin(angle) * radius

	return (forward + offset).normalized()
