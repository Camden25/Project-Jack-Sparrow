extends WeaponBase
class_name HitscanWeapon

@export var max_range: float = 100.0

func _fire(origin: Vector3, direction: Vector3):
	var shooter_id = multiplayer.get_unique_id()
	if multiplayer.is_server():
		_server_validate_shot_local(origin, direction, shooter_id)
	else:
		_server_validate_shot.rpc_id(1, origin, direction, shooter_id)

func _server_validate_shot_local(origin: Vector3, direction: Vector3, shooter_id: int):
	_run_validation(origin, direction, shooter_id)

@rpc("any_peer", "call_remote", "reliable")
func _server_validate_shot(origin: Vector3, direction: Vector3, shooter_id: int):
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != shooter_id:
		push_error("Shooter ID mismatch")
		return
	_run_validation(origin, direction, shooter_id)

func _run_validation(origin: Vector3, direction: Vector3, shooter_id: int):
	var world = get_tree().get_root().get_node_or_null("World")
	if world:
		world.spawn_tracer(get_node("TracerSpawn").global_position, direction)
	
	var now = Time.get_ticks_msec() / 1000.0
	var ping = NetworkManager.get_peer_ping(shooter_id)
	var rewind_time = clampf(now - ping, now - 0.3, now)
	
	var rewound_positions = _rewind_players(rewind_time, shooter_id)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * max_range)
	var shooter_node = get_tree().get_root().get_node_or_null("World/Players/" + str(shooter_id))
	if shooter_node:
		query.exclude = [shooter_node.get_rid()]
	
	var result = space_state.intersect_ray(query)
	_restore_players(rewound_positions)
	
	if result and result.collider:
		var player = _find_player_root(result.collider)
		if player:
			var health_component = player.get_node_or_null("PlayerHealth")
			if health_component:
				if PlayerManager.is_same_team(shooter_id, player.get_multiplayer_authority()):
					return
				health_component.apply_damage(damage, shooter_id)
				MatchEvents.confirm_hit.rpc(shooter_id, int(player.name))

func _rewind_players(timestamp: float, shooter_id: int) -> Dictionary:
	var original_positions = {}
	var players_node = get_tree().get_root().get_node_or_null("World/Players")
	if not players_node:
		return original_positions
	
	for player in players_node.get_children():
		if not player is CharacterBody3D:
			continue
		if player.get_multiplayer_authority() == shooter_id:
			continue
		var buffer = player.get_node_or_null("LagCompensationBuffer")
		if not buffer:
			continue
		
		original_positions[player] = {
			"position": player.global_position,
			"basis": player.global_basis
		}
		
		var rewound = buffer.get_position_at(timestamp)
		var rewound_transform = Transform3D(rewound.basis, rewound.position)
		
		player.global_transform = rewound_transform
		PhysicsServer3D.body_set_state(
			player.get_rid(),
			PhysicsServer3D.BODY_STATE_TRANSFORM,
			rewound_transform
		)
	
	return original_positions

func _restore_players(original_positions: Dictionary):
	for player in original_positions:
		var restore_transform = Transform3D(
			original_positions[player].basis,
			original_positions[player].position
		)
		player.global_transform = restore_transform
		PhysicsServer3D.body_set_state(
			player.get_rid(),
			PhysicsServer3D.BODY_STATE_TRANSFORM,
			restore_transform
		)

func _find_player_root(node: Node) -> Node:
	var current = node
	while current:
		if current is CharacterBody3D and current.get_node_or_null("PlayerHealth"):
			return current
		current = current.get_parent()
	return null

func _play_hit_effect():
	pass
