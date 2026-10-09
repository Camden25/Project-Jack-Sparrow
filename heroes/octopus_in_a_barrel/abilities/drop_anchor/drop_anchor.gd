extends Ability
class_name DropAnchorAbility

const ANCHOR_DAMAGE_BASE: int = 30
const ANCHOR_DAMAGE_PER_METER: float = 3.0
const ANCHOR_MAX_DAMAGE: int = 80

var anchor_spawn_pos: Vector3 = Vector3.ZERO
var anchor_spawn_offset: Vector3 = Vector3(0, -1.0, 0)

var anchor_landed: bool = false
var anchor_land_position: Vector3 = Vector3.ZERO
var _anchor_notification_received: bool = false

# Override try_activate to prevent base class starting cooldown
func try_activate():
	if not _can_activate():
		return
	_activate()

func _activate():
	_reset_state()
	anchor_spawn_pos = owner_player.global_position + anchor_spawn_offset
	owner_player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.3).timeout
	_drop_anchor()

func _reset_state():
	anchor_landed = false
	_anchor_notification_received = false

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
	anchor_landed = false
	_anchor_notification_received = false

func notify_anchor_landed(land_pos: Vector3, victims: Array, drop_height: float):
	if _anchor_notification_received:
		return
	_anchor_notification_received = true
	_on_anchor_landed.rpc(land_pos, victims, drop_height)

@rpc("any_peer", "call_local", "reliable")
func _on_anchor_landed(land_pos: Vector3, victims: Array, drop_height: float):
	anchor_landed = true
	anchor_land_position = land_pos
	
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

func _can_activate() -> bool:
	if owner_player.is_on_floor() == true:
		return false
	return super._can_activate()

func _calculate_damage(drop_height: float) -> int:
	var damage = ANCHOR_DAMAGE_BASE + int(drop_height * ANCHOR_DAMAGE_PER_METER)
	return min(damage, ANCHOR_MAX_DAMAGE)
