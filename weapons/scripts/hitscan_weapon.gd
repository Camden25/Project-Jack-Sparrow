extends WeaponBase
class_name HitscanWeapon

@export var max_range: float = 100.0

# Called on the local client when player fires
func _fire(origin: Vector3, direction: Vector3):
	var timestamp = Time.get_ticks_msec() / 1000.0
	var shooter_id = multiplayer.get_unique_id()
	
	# ssa validation
	_server_validate_shot.rpc_id(1, origin, direction, timestamp, shooter_id)

# server only
@rpc("any_peer", "call_local", "reliable")
func _server_validate_shot(origin: Vector3, direction: Vector3, timestamp: float, shooter_id: int):
	var sender_id = multiplayer.get_remote_sender_id()
	
	if sender_id != shooter_id:
		push_error("Shooter ID mismatch")
		return
	
	_spawn_tracer_server(origin, direction)
	
	# Get sender's ping to determine rewind amount
	var ping = _get_peer_ping(sender_id)
	var rewind_time = timestamp - ping
	
	# Rewind all players to rewind_time
	var rewound_positions = _rewind_players(rewind_time, sender_id)
	
	# Run authoritative raycast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * max_range)
	query.exclude = [get_parent()]  # exclude shooter
	var result = space_state.intersect_ray(query)
	
	# Restore all players
	_restore_players(rewound_positions)
	
	if result and result.collider:
		var hit_node = result.collider
		# Walk up tree to find player root
		var player = _find_player_root(hit_node)
		if player:
			var health_component = player.get_node_or_null("PlayerHealth")
			if health_component:
				health_component.apply_damage(damage, sender_id)
				MatchEvents.confirm_hit.rpc(sender_id, int(player.name))

func _spawn_tracer_server(origin: Vector3, direction: Vector3):
	var projectiles_node = get_tree().get_root().get_node_or_null("World/Projectiles")
	if not projectiles_node:
		return
	var tracer = preload("res://weapons/scenes/tracer.tscn").instantiate()
	tracer.start_pos = origin
	tracer.direction = direction
	projectiles_node.add_child(tracer)  # MultiplayerSpawner auto-replicates this

# Rewinds all players except shooter, returns their original positions
func _rewind_players(timestamp: float, shooter_id: int) -> Dictionary:
	var original_positions = {}
	var players_node = get_tree().get_root().get_node_or_null("World/Players")
	if not players_node:
		return original_positions
	
	for player in players_node.get_children():
		if not player is CharacterBody3D:
			continue
		if player.get_multiplayer_authority() == shooter_id:
			continue  # don't rewind shooter
		
		var buffer = player.get_node_or_null("LagCompensationBuffer")
		if not buffer:
			continue
		
		original_positions[player] = {
			"position": player.global_position,
			"basis": player.global_basis
		}
		
		var rewound = buffer.get_position_at(timestamp)
		player.global_position = rewound.position
		player.global_basis = rewound.basis
	
	return original_positions

func _restore_players(original_positions: Dictionary):
	for player in original_positions:
		player.global_position = original_positions[player].position
		player.global_basis = original_positions[player].basis

func _get_peer_ping(peer_id: int) -> float:
	# GodotSteam has ping via Steam networking
	return 0.05  # assume 50ms temporarily

func _find_player_root(node: Node) -> Node:
	var current = node
	while current:
		if current is CharacterBody3D and current.get_node_or_null("PlayerHealth"):
			return current
		current = current.get_parent()
	return null

func _play_hit_effect():
	pass  # placeholder for hit marker UI
