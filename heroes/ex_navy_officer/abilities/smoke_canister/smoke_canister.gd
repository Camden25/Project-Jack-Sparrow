extends Ability
class_name SmokeCanisterAbility

@export var throw_force: float = 15.0
@export var smoke_duration: float = 6.0
@export var smoke_radius: float = 8.0

func _activate():
	var origin = owner_player.get_node("Head/Camera3D").global_position
	var impulse = (-owner_player.get_node("Head/Camera3D").global_basis.z + Vector3(0, 0.3, 0)) * throw_force
	
	if multiplayer.is_server():
		_request_spawn(origin, impulse)
	else:
		_request_spawn.rpc_id(1, origin, impulse)

@rpc("any_peer", "call_remote", "reliable")
func _request_spawn(origin: Vector3, impulse: Vector3):
	if not multiplayer.is_server():
		return
	var world = SceneManager.get_world()
	if world:
		world.spawn_projectile("smoke_canister", {
			"origin": origin,
			"impulse": impulse,
			"shooter_id": owner_player.get_multiplayer_authority(),
			"duration": smoke_duration,
			"radius": smoke_radius
		})
