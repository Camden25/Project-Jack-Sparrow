extends Projectile
class_name QuickDoseProjectile

const PLAYER_COLLISION_MASK: int = 2
const IMPACT_LINGER_SECONDS: float = 0.15

var _pending_origin: Vector3 = Vector3.ZERO
var _initial_velocity: Vector3 = Vector3.ZERO
var _gravity: Vector3 = Vector3.DOWN * 9.8
var _heal_amount: int = 20
var _burst_radius: float = 3.0
var _detonated: bool = false

func init_from_data(data: Dictionary):
	super.init_from_data(data)
	shooter_id = data.get("shooter_id", -1)
	_pending_origin = data.get("origin", Vector3.ZERO)
	_initial_velocity = data.get("initial_velocity", Vector3.ZERO)
	_gravity = data.get("gravity", Vector3.DOWN * 9.8)
	lifetime = data.get("lifetime", lifetime)
	_heal_amount = maxi(int(data.get("heal_amount", 20)), 0)
	_burst_radius = maxf(float(data.get("burst_radius", _burst_radius)), 0.0)

func _ready():
	global_position = _pending_origin
	linear_velocity = _initial_velocity
	gravity_scale = 0.0
	custom_integrator = true
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	body_entered.connect(_on_body_entered)

	if not multiplayer.is_server():
		return

	var shooter := _get_player_node(shooter_id)
	if shooter is PhysicsBody3D:
		add_collision_exception_with(shooter)
	broadcast_visual_launch(
		"quick_dose",
		_pending_origin,
		_initial_velocity,
		_gravity,
		lifetime
	)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not _detonated:
		state.linear_velocity += _gravity * state.step

func _physics_process(delta: float):
	if not multiplayer.has_multiplayer_peer() or _detonated or not multiplayer.is_server():
		return
	super._physics_process(delta)

func _on_body_entered(body: Node):
	if not multiplayer.is_server() or _detonated:
		return
	if body is CharacterBody3D and body.get_multiplayer_authority() == shooter_id:
		return
	_detonated = true
	call_deferred("_detonate")

func _detonate() -> void:
	freeze = true
	linear_velocity = Vector3.ZERO
	_heal_allies_in_burst()
	broadcast_visual_impact(global_position, Vector3.UP, IMPACT_LINGER_SECONDS)

	await get_tree().create_timer(IMPACT_LINGER_SECONDS).timeout
	if is_instance_valid(self):
		queue_free()

func _heal_allies_in_burst() -> void:
	if _burst_radius <= 0.0:
		return

	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = _burst_radius
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = PLAYER_COLLISION_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]

	var seen_targets: Dictionary = {}
	var space_state := get_world_3d().direct_space_state
	for result in space_state.intersect_shape(query, 32):
		var collider := result.get("collider") as Node
		var target := _find_player_root(collider) if collider else null
		if not target or seen_targets.has(target.get_instance_id()):
			continue
		seen_targets[target.get_instance_id()] = true
		if not _is_ally_target(target):
			continue
		var distance := global_position.distance_to(target.global_position)
		if distance > _burst_radius or not _has_clear_healing_line(target):
			continue
		var health := target.get_node_or_null("PlayerHealth") as PlayerHealth
		if health:
			health.apply_healing(_heal_amount, shooter_id)

func _is_ally_target(target: Node) -> bool:
	if target == _get_player_node(shooter_id):
		return false
	if target is PracticeDummy:
		return target.is_ally
	if target is Player:
		var owner_team := PlayerManager.get_team(shooter_id)
		return (
			owner_team != PlayerManager.Team.NONE
			and PlayerManager.get_team(target.get_multiplayer_authority()) == owner_team
		)
	return false

func _has_clear_healing_line(target: Node3D) -> bool:
	var target_point := target.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(
		global_position,
		target_point,
		1,
		[get_rid()]
	)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	return _find_player_root(result["collider"] as Node) == target

func _find_player_root(node: Node) -> Node3D:
	if not is_instance_valid(node):
		return null
	var current := node
	while current:
		if current is CharacterBody3D and current.get_node_or_null("PlayerHealth"):
			return current as Node3D
		current = current.get_parent()
	return null

func _get_player_node(peer_id: int) -> Node:
	var players_node := SceneManager.get_players_node()
	if players_node:
		return players_node.get_node_or_null(str(peer_id))
	return null
