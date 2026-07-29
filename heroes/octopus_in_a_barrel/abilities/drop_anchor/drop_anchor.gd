extends Ability
class_name DropAnchorAbility

@export var auto_yank: bool = true

const RISE_SPEED: float = 14.0
const RISE_HEIGHT: float = 2.5
const ANCHOR_DAMAGE_BASE: int = 30
const ANCHOR_DAMAGE_PER_METER: float = 3.0
const ANCHOR_MAX_DAMAGE: int = 80
const YANK_SPEED: float = 50.0
const YANK_DURATION: float = 0.3

enum Phase { IDLE, RISING, DROPPING_ANCHOR, YANKING }
var phase: Phase = Phase.IDLE

var rise_start_y: float = 0.0
var rise_target_y: float = 0.0
var anchor_spawn_pos: Vector3 = Vector3.ZERO

var anchor_spawn_offset: Vector3 = Vector3(0, -1.0, 0)

var anchor_landed: bool = false
var anchor_land_position: Vector3 = Vector3.ZERO
var waiting_for_yank_input: bool = false

var yank_timer: float = 0.0
var yank_direction: Vector3 = Vector3.ZERO

func _activate():
	if phase == Phase.IDLE and waiting_for_yank_input:
		_begin_yank()
		return
	
	if phase != Phase.IDLE:
		return
	
	phase = Phase.RISING
	rise_start_y = owner_player.global_position.y
	rise_target_y = rise_start_y + RISE_HEIGHT
	owner_player.movement_override = true

func physics_update(delta: float):
	if not owner_player or not owner_player.is_multiplayer_authority():
		return
	
	match phase:
		Phase.RISING:
			_do_rise(delta)
		Phase.YANKING:
			_do_yank(delta)

func _do_rise(delta: float):
	owner_player.velocity.x = 0.0
	owner_player.velocity.z = 0.0
	owner_player.velocity.y = RISE_SPEED
	
	if owner_player.global_position.y >= rise_target_y:
		owner_player.velocity.y = 0.0
		owner_player.global_position.y = rise_target_y
		phase = Phase.DROPPING_ANCHOR
		anchor_spawn_pos = owner_player.global_position + anchor_spawn_offset
		_drop_anchor()

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
		return
	world.spawn_projectile("anchor", {
		"origin": spawn_pos,
		"shooter_id": owner_player.get_multiplayer_authority(),
		"rise_height": RISE_HEIGHT
	})
	_notify_anchor_spawned.rpc(spawn_pos)

@rpc("any_peer", "call_local", "reliable")
func _notify_anchor_spawned(_spawn_pos: Vector3):
	waiting_for_yank_input = not auto_yank

func notify_anchor_landed(land_pos: Vector3, victims: Array, drop_height: float):
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
	
	if auto_yank:
		_begin_yank()
	
	_reset_after_yank.call_deferred()

func _reset_after_yank():
	await owner_player.get_tree().create_timer(YANK_DURATION + 0.5).timeout
	if phase != Phase.IDLE:
		phase = Phase.IDLE
		anchor_landed = false
		if owner_player:
			owner_player.movement_override = false

func _begin_yank():
	waiting_for_yank_input = false
	phase = Phase.YANKING
	yank_timer = YANK_DURATION
	
	if not owner_player.is_multiplayer_authority():
		return
	
	yank_direction = (anchor_land_position - owner_player.global_position).normalized()
	if data and data.cooldown > 0:
		_start_cooldown()

func _do_yank(delta: float):
	yank_timer -= delta
	if yank_timer <= 0:
		phase = Phase.IDLE
		owner_player.movement_override = false
		anchor_landed = false
		return
	
	owner_player.velocity = yank_direction * YANK_SPEED

func _can_activate() -> bool:
	if waiting_for_yank_input:
		return true
	return super._can_activate()

func _calculate_damage(drop_height: float) -> int:
	var damage = ANCHOR_DAMAGE_BASE + int(drop_height * ANCHOR_DAMAGE_PER_METER)
	return min(damage, ANCHOR_MAX_DAMAGE)
