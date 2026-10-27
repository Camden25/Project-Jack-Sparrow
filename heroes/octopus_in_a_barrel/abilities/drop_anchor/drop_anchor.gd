extends Ability
class_name DropAnchorAbility

const ANCHOR_DAMAGE_BASE: int = 30
const ANCHOR_DAMAGE_PER_METER: float = 3.0
const ANCHOR_MAX_DAMAGE: int = 80
const LIFT_SPEED: float = 14.0
const LIFT_HEIGHT: float = 1.5
const LIFT_TIMEOUT: float = 0.35
const DROP_DELAY: float = 0.08
const PULL_SPEED: float = 42.0
const PULL_DURATION: float = 0.35
const PULL_MAX_DURATION: float = 3.0
const ANCHOR_LANDING_TIMEOUT: float = 4.0
const PULL_ARRIVAL_DISTANCE: float = 0.8

enum Phase { IDLE, LIFTING, DROPPING, WAITING_FOR_LANDING, PULLING }
var phase: Phase = Phase.IDLE
var phase_timer: float = 0.0
var lift_target_y: float = 0.0

var anchor_spawn_pos: Vector3 = Vector3.ZERO
var anchor_spawn_offset: Vector3 = Vector3(0, -1.0, 0)

var anchor_landed: bool = false
var anchor_land_position: Vector3 = Vector3.ZERO
var _anchor_notification_received: bool = false

func _activate():
	_reset_state()
	owner_player.velocity = Vector3.ZERO
	owner_player.movement_override = true
	
	var lift_room = _get_lift_room()
	if lift_room <= 0.1:
		_begin_drop()
		return
	
	lift_target_y = owner_player.global_position.y + minf(LIFT_HEIGHT, lift_room - 0.1)
	phase_timer = 0.0
	phase = Phase.LIFTING

func _reset_state():
	phase = Phase.IDLE
	phase_timer = 0.0
	anchor_landed = false
	_anchor_notification_received = false
	if owner_player:
		owner_player.movement_override = false

func _get_lift_room() -> float:
	var space = owner_player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		owner_player.global_position,
		owner_player.global_position + Vector3.UP * LIFT_HEIGHT
	)
	query.exclude = [owner_player.get_rid()]
	var result = space.intersect_ray(query)
	if result.is_empty():
		return LIFT_HEIGHT
	return maxf(result.position.y - owner_player.global_position.y, 0.0)

func _begin_drop():
	phase = Phase.DROPPING
	phase_timer = DROP_DELAY
	anchor_spawn_pos = owner_player.global_position + anchor_spawn_offset
	owner_player.velocity = Vector3.ZERO

func physics_update(delta: float):
	if not owner_player or not owner_player.is_multiplayer_authority():
		return

	match phase:
		Phase.LIFTING:
			phase_timer += delta
			owner_player.velocity = Vector3(0.0, LIFT_SPEED, 0.0)
			if owner_player.global_position.y >= lift_target_y or phase_timer >= LIFT_TIMEOUT:
				owner_player.velocity = Vector3.ZERO
				_begin_drop()
		Phase.DROPPING:
			phase_timer -= delta
			owner_player.velocity = Vector3.ZERO
			if phase_timer <= 0.0:
				_drop_anchor()
				phase = Phase.WAITING_FOR_LANDING
				phase_timer = ANCHOR_LANDING_TIMEOUT
		Phase.WAITING_FOR_LANDING:
			phase_timer -= delta
			owner_player.velocity = Vector3.ZERO
			if phase_timer <= 0.0 or not owner_player.spawn_confirmed:
				_finish_movement()
		Phase.PULLING:
			phase_timer -= delta
			var to_anchor = anchor_land_position - owner_player.global_position
			if phase_timer <= 0.0 or to_anchor.length() <= PULL_ARRIVAL_DISTANCE or owner_player.get_slide_collision_count() > 0:
				_finish_movement()
			else:
				owner_player.velocity = to_anchor.normalized() * PULL_SPEED

func _drop_anchor():
	if multiplayer.is_server():
		_spawn_anchor(anchor_spawn_pos)
	else:
		_spawn_anchor.rpc_id(1, anchor_spawn_pos)

@rpc("any_peer", "call_remote", "reliable")
func _spawn_anchor(spawn_pos: Vector3):
	if not multiplayer.is_server():
		return
	var world = SceneManager.get_world()
	if not world:
		_force_reset()
		return
	world.spawn_projectile("anchor", {
		"origin": spawn_pos,
		"shooter_id": owner_player.get_multiplayer_authority(),
	})
	_notify_anchor_spawned.rpc(spawn_pos)

@rpc("any_peer", "call_local", "reliable")
func _notify_anchor_spawned(_spawn_pos: Vector3):
	pass

func _force_reset():
	_reset_state()

func notify_anchor_landed(land_pos: Vector3, victims: Array, drop_height: float):
	if _anchor_notification_received:
		return
	_anchor_notification_received = true
	_on_anchor_landed.rpc(land_pos, victims, drop_height)

@rpc("any_peer", "call_local", "reliable")
func _on_anchor_landed(land_pos: Vector3, victims: Array, drop_height: float):
	anchor_landed = true
	anchor_land_position = land_pos
	if owner_player.is_multiplayer_authority():
		_start_cooldown()
		if phase == Phase.WAITING_FOR_LANDING:
			owner_player.movement_override = true
			phase = Phase.PULLING
			var pull_distance = owner_player.global_position.distance_to(anchor_land_position)
			phase_timer = minf(
				PULL_MAX_DURATION,
				maxf(PULL_DURATION, pull_distance / PULL_SPEED + 0.15)
			)
	
	if multiplayer.is_server():
		var damage = _calculate_damage(drop_height)
		for peer_id in victims:
			var players_node = SceneManager.get_players_node()
			if not players_node:
				continue
			var victim = players_node.get_node_or_null(str(peer_id))
			if not victim:
				continue
			var health = victim.get_node_or_null("PlayerHealth")
			if health:
				health.apply_damage(damage, owner_player.get_multiplayer_authority())
				owner_player.emit_signal("damage_dealt", damage)

func _finish_movement():
	phase = Phase.IDLE
	phase_timer = 0.0
	owner_player.velocity = Vector3.ZERO
	owner_player.movement_override = false

func _can_activate() -> bool:
	if phase != Phase.IDLE or not owner_player.spawn_confirmed or owner_player.is_on_floor():
		return false
	return super._can_activate()

func _calculate_damage(drop_height: float) -> int:
	var damage = ANCHOR_DAMAGE_BASE + int(drop_height * ANCHOR_DAMAGE_PER_METER)
	return min(damage, ANCHOR_MAX_DAMAGE)
