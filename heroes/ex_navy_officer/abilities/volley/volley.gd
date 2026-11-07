extends UltimateAbility
class_name VolleyUltimate

@export var num_shots: int = 5
@export var spread_radius: float = 3.0
@export var damage_per_shot: int = 60
@export var warning_duration: float = 1.5
@export var shot_interval: float = 0.1

var is_volley_active: bool = false

func _can_activate() -> bool:
	return not is_volley_active and super._can_activate()

func _activate():
	if not owner_player.is_multiplayer_authority():
		return
	
	# Target point is where the player is looking, projected onto the ground
	var camera = owner_player.get_node("Head/Camera3D")
	var target = _get_target_point(camera)
	is_volley_active = true

	if multiplayer.is_server():
		_fire_volley(target)
	else:
		_fire_volley.rpc_id(1, target)

func _get_target_point(camera: Camera3D) -> Vector3:
	var space_state = owner_player.get_world_3d().direct_space_state
	var origin = camera.global_position
	var direction = -camera.global_basis.z
	var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	# If no hit, project forward onto a flat plane
	return origin + direction * 30.0

@rpc("any_peer", "call_remote", "reliable")
func _fire_volley(target: Vector3):
	if not multiplayer.is_server():
		return

	var sender_id = multiplayer.get_remote_sender_id()
	var owner_peer_id = owner_player.get_multiplayer_authority()
	if sender_id != 0 and sender_id != owner_peer_id:
		return
	if is_volley_active and not (sender_id == 0 and owner_peer_id == 1):
		return
	if not is_ready():
		_cancel_volley()
		return

	var projectile_events = SceneManager.get_projectile_events()
	if not projectile_events:
		push_error("VolleyUltimate: ProjectileEvents not found")
		_cancel_volley()
		return

	is_volley_active = true
	projectile_events.broadcast_effect("volley_flare", target + Vector3(0, 0.1, 0), warning_duration)
	
	# Wait for warning duration
	await owner_player.get_tree().create_timer(warning_duration).timeout
	
	if not is_instance_valid(owner_player):
		return
	
	# Fire shots in spread pattern around target
	for i in num_shots:
		var offset = Vector3(
			randf_range(-spread_radius, spread_radius),
			0,
			randf_range(-spread_radius, spread_radius)
		)
		var shot_pos = target + offset
		
		# Raycast straight down at each shot position
		var space_state = owner_player.get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			shot_pos + Vector3(0, 20, 0),
			shot_pos + Vector3(0, -5, 0)
		)
		var result = space_state.intersect_ray(query)
		
		if result and result.collider:
			var player = _find_player_root(result.collider)
			if player and (
				player.is_in_group("practice_dummies")
				or player.get_multiplayer_authority() != owner_player.get_multiplayer_authority()
			):
				if player.is_in_group("practice_dummies") or not PlayerManager.is_same_team(
					owner_player.get_multiplayer_authority(),
					player.get_multiplayer_authority()
				):
					var health = player.get_node_or_null("PlayerHealth")
					if health:
						health.apply_damage(damage_per_shot, owner_player.get_multiplayer_authority())
						owner_player.emit_signal("damage_dealt", damage_per_shot)
		
		# Spawn visual for each shot
		var impact_position = result.position if result else shot_pos
		projectile_events.broadcast_effect("volley_shot", impact_position, maxf(shot_interval * 2.0, 0.2))
		
		await owner_player.get_tree().create_timer(shot_interval).timeout
	
	# Reset charge
	_use_ultimate()
	_finish_volley.rpc_id(owner_peer_id)
	is_volley_active = false

func _find_player_root(node: Node) -> Node:
	var current = node
	while current:
		if current is CharacterBody3D and current.get_node_or_null("PlayerHealth"):
			return current
		current = current.get_parent()
	return null

func _cancel_volley():
	is_volley_active = false
	var owner_peer_id = owner_player.get_multiplayer_authority()
	if owner_peer_id != 1:
		_finish_volley.rpc_id(owner_peer_id)

@rpc("authority", "call_remote", "reliable")
func _finish_volley():
	is_volley_active = false
