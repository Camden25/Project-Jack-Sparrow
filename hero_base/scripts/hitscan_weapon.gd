extends Weapon
class_name HitscanWeaponBase

@export var headshot_multiplier: float = 1.5
@export var muzzle_point_path: NodePath
@onready var muzzle: Marker3D = get_node_or_null(muzzle_point_path)

func _fire():
	if not owner_player:
		return
	
	var camera = owner_player.get_node("Head/Camera3D")
	var direction = _get_fire_direction()
	var shooter_id = multiplayer.get_unique_id()
	
	var tracer_origin = camera.global_position
	if muzzle:
		tracer_origin = muzzle.global_position
	
	_spawn_tracer(tracer_origin, direction)
	
	if multiplayer.is_server():
		_run_validation(camera.global_position, direction, shooter_id)
	else:
		_server_validate_shot.rpc_id(1, camera.global_position, direction, shooter_id)

func _get_fire_direction() -> Vector3:
	# Override for spread weapons like shotgun
	return -owner_player.get_node("Head/Camera3D").global_basis.z

func _spawn_tracer(origin: Vector3, direction: Vector3):
	var effects_manager = SceneManager.get_effects_manager()
	if effects_manager:
		effects_manager.spawn_tracer(origin, direction)

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
	var now = Time.get_ticks_msec() / 1000.0
	var ping = NetworkManager.get_peer_ping(shooter_id)
	var rewind_time = clampf(now - ping, now - 0.3, now)
	
	var rewound_positions = _rewind_players(rewind_time, shooter_id)
	
	var space_state = owner_player.get_world_3d().direct_space_state
	var result = _do_raycast(space_state, origin, direction, shooter_id)
	
	_restore_players(rewound_positions)
	
	if result and result.collider:
		var player = _find_player_root(result.collider)
		if player:
			var health_component = player.get_node_or_null("PlayerHealth")
			if health_component:
				if PlayerManager.is_same_team(shooter_id, player.get_multiplayer_authority()):
					return
				var damage_to_deal = _calculate_damage(result)
				health_component.apply_damage(damage_to_deal, shooter_id)
				# Emit damage dealt signal for ultimate charge
				var shooter_node = _get_player_node(shooter_id)
				if shooter_node:
					shooter_node.emit_signal("damage_dealt", damage_to_deal)
				MatchEvents.confirm_hit.rpc(shooter_id, int(player.name))

func _do_raycast(space_state: PhysicsDirectSpaceState3D, origin: Vector3, direction: Vector3, shooter_id: int) -> Dictionary:
	var query = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * data.max_range
	)
	var shooter_node = _get_player_node(shooter_id)
	if shooter_node:
		query.exclude = [shooter_node.get_rid()]
	return space_state.intersect_ray(query)

@warning_ignore("unused_parameter")
func _calculate_damage(result: Dictionary) -> int:
	# Override for headshot detection
	return data.damage

func _rewind_players(timestamp: float, shooter_id: int) -> Dictionary:
	var original_positions = {}
	var players_node = SceneManager.get_players_node()
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

func _get_player_node(peer_id: int) -> Node:
	var players_node = SceneManager.get_players_node()
	if players_node:
		return players_node.get_node(str(peer_id))
	return null
