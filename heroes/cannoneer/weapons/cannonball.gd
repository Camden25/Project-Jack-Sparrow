extends Projectile
class_name CannonballProjectile

const WORLD_COLLISION_MASK: int = 1
const PLAYER_COLLISION_MASK: int = 2
const IMPACT_LINGER_SECONDS: float = 0.15

var _pending_origin: Vector3 = Vector3.ZERO
var _initial_velocity: Vector3 = Vector3.ZERO
var _gravity: Vector3 = Vector3.DOWN * 9.8
var _splash_damage: int = 30
var _splash_radius: float = 4.0
var _detonated: bool = false

func init_from_data(data: Dictionary):
	super.init_from_data(data)
	shooter_id = data.get("shooter_id", -1)
	_pending_origin = data.get("origin", Vector3.ZERO)
	_initial_velocity = data.get("initial_velocity", Vector3.ZERO)
	_gravity = data.get("gravity", Vector3.DOWN * 9.8)
	lifetime = data.get("lifetime", lifetime)
	damage = data.get("damage", damage)
	_splash_damage = maxi(int(data.get("splash_damage", _splash_damage)), 0)
	_splash_radius = maxf(float(data.get("splash_radius", _splash_radius)), 0.0)

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
		"cannonball",
		_pending_origin,
		_initial_velocity,
		_gravity,
		lifetime
	)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if multiplayer.has_multiplayer_peer() == false:
		return
	if multiplayer.is_server() and not _detonated:
		state.linear_velocity += _gravity * state.step

func _physics_process(delta: float):
	if multiplayer.has_multiplayer_peer() == false:
		return
	if _detonated or not multiplayer.is_server():
		return
	super._physics_process(delta)

func _on_body_entered(body: Node):
	if not multiplayer.is_server() or _detonated:
		return
	_detonated = true
	call_deferred("_detonate", body)

func _detonate(direct_hit: Node):
	freeze = true
	linear_velocity = Vector3.ZERO
	_apply_direct_damage(direct_hit)
	_apply_splash_damage(direct_hit)
	broadcast_visual_impact(global_position, Vector3.UP, IMPACT_LINGER_SECONDS)

	await get_tree().create_timer(IMPACT_LINGER_SECONDS).timeout
	if is_instance_valid(self):
		queue_free()

func _apply_direct_damage(body: Node):
	var target := _find_player_root(body)
	if not target:
		return
	if not target.is_in_group("practice_dummies") and (
		target.get_multiplayer_authority() == shooter_id
		or PlayerManager.is_same_team(shooter_id, target.get_multiplayer_authority())
	):
		return
	_damage_player(target, damage)

func _apply_splash_damage(direct_hit: Node):
	if _splash_damage <= 0 or _splash_radius <= 0.0:
		return

	var space_state := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = _splash_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = PLAYER_COLLISION_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]

	var shooter := _get_player_node(shooter_id)
	if shooter is PhysicsBody3D:
		query.exclude.append(shooter.get_rid())

	var directly_hit_player := _find_player_root(direct_hit)
	var direct_hit_instance_id := directly_hit_player.get_instance_id() if directly_hit_player else -1
	for result in space_state.intersect_shape(query, 32):
		var collider := result.get("collider") as Node
		var target := _find_player_root(collider) if collider else null
		if not target or target.get_instance_id() == direct_hit_instance_id:
			continue
		if not target.is_in_group("practice_dummies") and PlayerManager.is_same_team(
			shooter_id,
			target.get_multiplayer_authority()
		):
			continue

		var distance := global_position.distance_to(target.global_position)
		if distance > _splash_radius or not _has_clear_splash_line(target):
			continue
		var damage_scale := 1.0 - distance / _splash_radius
		var splash_amount := roundi(float(_splash_damage) * damage_scale)
		if splash_amount > 0:
			_damage_player(target, splash_amount)

func _has_clear_splash_line(target: Node3D) -> bool:
	var target_point := target.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(
		global_position,
		target_point,
		WORLD_COLLISION_MASK,
		[get_rid()]
	)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _damage_player(target: Node, amount: int):
	var health := target.get_node_or_null("PlayerHealth") as PlayerHealth
	if not health or health.health <= 0:
		return

	var health_before := health.health
	health.apply_damage(amount, shooter_id)
	var actual_damage := health_before - health.health
	if actual_damage <= 0:
		return

	var shooter := _get_player_node(shooter_id)
	if shooter and shooter.has_signal("damage_dealt"):
		shooter.emit_signal("damage_dealt", actual_damage)
	MatchEvents.confirm_hit.rpc(shooter_id, target.get_multiplayer_authority())

func _get_player_node(peer_id: int) -> Node:
	var players_node := SceneManager.get_players_node()
	if players_node:
		return players_node.get_node_or_null(str(peer_id))
	return null

func _find_player_root(node: Node) -> Node3D:
	if not is_instance_valid(node):
		return null
	var current := node
	while current:
		if current is CharacterBody3D and current.get_node_or_null("PlayerHealth"):
			return current as Node3D
		current = current.get_parent()
	return null
