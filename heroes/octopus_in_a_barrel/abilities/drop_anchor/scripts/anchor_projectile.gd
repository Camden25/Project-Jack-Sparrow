extends Projectile
class_name AnchorProjectile

var _ability_node: DropAnchorAbility = null
var _pending_origin: Vector3 = Vector3.ZERO
var _spawn_height: float = 0.0
var _has_landed: bool = false
var _last_contact_normal: Vector3 = Vector3.UP

const ANCHOR_FALL_SPEED: float = 60.0
const WORLD_COLLISION_MASK: int = 1

func init_from_data(data: Dictionary):
	super.init_from_data(data)
	shooter_id = data.get("shooter_id", -1)
	_pending_origin = data.get("origin", Vector3.ZERO)
	_spawn_height = _pending_origin.y

func _ready():
	global_position = _pending_origin
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	body_entered.connect(_on_body_entered)
	
	if not multiplayer.is_server():
		return
	
	var players_node = SceneManager.get_players_node()
	if players_node:
		var shooter = players_node.get_node_or_null(str(shooter_id))
		if shooter:
			for child in shooter.get_node_or_null("Abilities").get_children():
				if child is DropAnchorAbility:
					_ability_node = child
					break
	
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	linear_velocity = Vector3(0, -ANCHOR_FALL_SPEED, 0)
	broadcast_visual_launch(
		"anchor",
		_pending_origin,
		Vector3(0.0, -ANCHOR_FALL_SPEED, 0.0),
		Vector3.ZERO,
		lifetime
	)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if state.get_contact_count() > 0:
		_last_contact_normal = state.get_contact_local_normal(0)

func _physics_process(delta: float):
	if multiplayer.has_multiplayer_peer() == false:
		return
	
	if not multiplayer.is_server() or _has_landed:
		return
	super._physics_process(delta)
	if _finished:
		return

	# Sweep ahead of the fast rigid body so thin floors cannot be skipped between frames.
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.DOWN * (ANCHOR_FALL_SPEED * delta + 0.25),
		WORLD_COLLISION_MASK,
		[get_rid()]
	)
	var result = space.intersect_ray(query)
	if not result.is_empty() and result.normal.dot(Vector3.UP) >= 0.3:
		_land_at(result.position + result.normal * 0.2, result.normal)
		return

	linear_velocity = Vector3(0, -ANCHOR_FALL_SPEED, 0)

func _on_body_entered(body: Node):
	if not multiplayer.is_server() or _has_landed:
		return
	if body is CharacterBody3D:
		return
	if _last_contact_normal.dot(Vector3.UP) < 0.3:
		return
	_land_at(global_position, _last_contact_normal)

func _land_at(land_position: Vector3, surface_normal: Vector3):
	if _has_landed or surface_normal.dot(Vector3.UP) < 0.3:
		return
	
	_has_landed = true
	global_position = land_position
	freeze = true
	linear_velocity = Vector3.ZERO
	broadcast_visual_impact(global_position, surface_normal, 1.5)
	
	var drop_height = maxf(_spawn_height - global_position.y, 0.0)
	var victims = []
	var players_node = SceneManager.get_players_node()
	if players_node:
		for player in players_node.get_children():
			if not player is CharacterBody3D:
				continue
			if player.get_multiplayer_authority() == shooter_id:
				continue
			if PlayerManager.is_same_team(shooter_id, player.get_multiplayer_authority()):
				continue
			if global_position.distance_to(player.global_position) <= DropAnchorAbility.ANCHOR_DAMAGE_RADIUS:
				victims.append(player.get_multiplayer_authority())
	
	if _ability_node:
		_ability_node.notify_anchor_landed(global_position, victims, drop_height)
	
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(self):
		broadcast_visual_finished()
		queue_free()
