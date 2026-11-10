extends SurgeonHealAbility
class_name QuickDose

@export_range(1, 100, 1) var heal_amount: int = 20
@export_range(5.0, 40.0, 0.5) var projectile_speed: float = 18.0
@export_range(0.0, 10.0, 0.5) var upward_velocity: float = 2.0
@export_range(0.5, 6.0, 0.1) var burst_radius: float = 3.0
@export_range(0.0, 1.0, 0.01) var max_aim_deviation: float = 0.35
@export_range(2.0, 12.0, 0.5) var projectile_lifetime: float = 6.0

func _activate():
	var camera := owner_player.get_node_or_null("Head/Camera3D") as Camera3D
	if not camera:
		push_error("QuickDose could not find the owner's camera")
		return

	var direction := -camera.global_basis.z.normalized()
	if multiplayer.is_server():
		_server_throw(multiplayer.get_unique_id(), direction)
	else:
		_request_throw.rpc_id(1, direction)

@rpc("any_peer", "call_remote", "reliable")
func _request_throw(direction: Vector3):
	if not multiplayer.is_server():
		return
	_server_throw(multiplayer.get_remote_sender_id(), direction)

func _server_throw(sender_id: int, requested_direction: Vector3) -> void:
	if (
		not is_instance_valid(owner_player)
		or not requested_direction.is_finite()
		or requested_direction.length_squared() < 0.0001
	):
		return

	var camera := owner_player.get_node_or_null("Head/Camera3D") as Camera3D
	if not camera:
		return

	var direction := requested_direction.normalized()
	var server_aim := -camera.global_basis.z.normalized()
	if direction.dot(server_aim) < 1.0 - max_aim_deviation:
		return
	var registry := SceneManager.get_projectile_registry()
	if not registry or not registry.get_scene("quick_dose"):
		push_error("QuickDose projectile is not registered")
		return

	if not _can_use_on_server(sender_id):
		return

	var origin := camera.global_position + direction * 0.7
	var world := SceneManager.get_world()
	if not world:
		push_error("QuickDose could not find the current World")
		return

	var projectile_id: int = world.spawn_projectile("quick_dose", {
		"shooter_id": owner_player.get_multiplayer_authority(),
		"origin": origin,
		"initial_velocity": direction * projectile_speed + Vector3.UP * upward_velocity,
		"gravity": Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity")),
		"lifetime": projectile_lifetime,
		"heal_amount": heal_amount,
		"burst_radius": burst_radius
	})
	if projectile_id < 0:
		return
	_validate_server_use(sender_id)
