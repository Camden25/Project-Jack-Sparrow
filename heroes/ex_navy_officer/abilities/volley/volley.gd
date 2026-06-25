extends UltimateAbility
class_name VolleyUltimate

@export var num_shots: int = 5
@export var spread_radius: float = 3.0
@export var damage_per_shot: int = 60
@export var warning_duration: float = 1.5
@export var shot_interval: float = 0.1

const FLARE_SCENE = preload("res://heroes/ex_navy_officer/abilities/volley/scenes/flare.tscn")
const VOLLEY_SHOT_SCENE = preload("res://heroes/ex_navy_officer/abilities/volley/scenes/volley_shot.tscn")

func _activate():
	if not owner_player.is_multiplayer_authority():
		return
	
	# Target point is where the player is looking, projected onto the ground
	var camera = owner_player.get_node("Head/Camera3D")
	var target = _get_target_point(camera)
	
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
	
	# Spawn flare at target for warning
	var world = owner_player.get_tree().get_root().get_node_or_null("World")
	if not world:
		return
	
	var flare = FLARE_SCENE.instantiate()
	world.get_node("Projectiles").add_child(flare)
	flare.global_position = target + Vector3(0, 0.1, 0)
	
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
			if player and player.get_multiplayer_authority() != owner_player.get_multiplayer_authority():
				if not PlayerManager.is_same_team(
					owner_player.get_multiplayer_authority(),
					player.get_multiplayer_authority()
				):
					var health = player.get_node_or_null("PlayerHealth")
					if health:
						health.apply_damage(damage_per_shot, owner_player.get_multiplayer_authority())
						owner_player.emit_signal("damage_dealt", damage_per_shot)
		
		# Spawn visual for each shot
		var shot_vfx = VOLLEY_SHOT_SCENE.instantiate()
		world.get_node("Projectiles").add_child(shot_vfx)
		if result:
			shot_vfx.global_position = result.position
		else:
			shot_vfx.global_position = shot_pos
		
		await owner_player.get_tree().create_timer(shot_interval).timeout
	
	# Reset charge
	_use_ultimate()

func _find_player_root(node: Node) -> Node:
	var current = node
	while current:
		if current is CharacterBody3D and current.get_node_or_null("PlayerHealth"):
			return current
		current = current.get_parent()
	return null
