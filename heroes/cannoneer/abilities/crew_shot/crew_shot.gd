extends Ability
class_name CrewShotAbility

enum Mode { NORMAL, PICKUP, SHOOT }

@export_range(1.0, 20.0, 0.5) var pickup_range: float = 8.0
@export_range(1.0, 40.0, 0.5) var launch_speed: float = 22.0
@export_range(0.0, 20.0, 0.5) var launch_lift: float = 8.0
@export_range(0.0, 180.0, 1.0) var max_aim_deviation_degrees: float = 75.0
@export_range(0.05, 1.0, 0.05) var invite_update_interval: float = 0.25
@export_range(0.1, 1.0, 0.05) var carrier_speed_multiplier: float = 0.65

var mode: int = Mode.NORMAL
var held_peer_id: int = -1
var held_dummy: PracticeDummy

var _invitation_id: int = 0
var _next_invitation_id: int = 0
var _invited_peers: Dictionary = {}
var _declined_peers: Dictionary = {}
var _invite_update_timer: float = 0.0
var _request_pending: bool = false

func _enter_tree():
	set_multiplayer_authority(1)

func try_activate():
	if not _can_activate():
		return
	_activate()

func _activate():
	if _request_pending:
		return
	_request_pending = true
	if multiplayer.is_server():
		_server_toggle(multiplayer.get_unique_id())
	else:
		_request_toggle.rpc_id(1)

func handle_primary_fire() -> bool:
	if mode == Mode.NORMAL:
		return false
	if mode == Mode.SHOOT:
		var camera := owner_player.get_node_or_null("Head/Camera3D") as Camera3D
		if camera and not _request_pending:
			_request_pending = true
			var direction := -camera.global_basis.z.normalized()
			if multiplayer.is_server():
				_server_launch(multiplayer.get_unique_id(), direction)
			else:
				_request_launch.rpc_id(1, direction)
	return true

func request_accept_from_client(invitation_id: int):
	if multiplayer.is_server():
		_server_accept(multiplayer.get_unique_id(), invitation_id)
	else:
		_request_accept.rpc_id(1, invitation_id)

func request_decline_from_client(invitation_id: int):
	if multiplayer.is_server():
		_server_decline(multiplayer.get_unique_id(), invitation_id)
	else:
		_request_decline.rpc_id(1, invitation_id)

func request_cancel_from_client():
	if multiplayer.is_server():
		_server_cancel_held(multiplayer.get_unique_id())
	else:
		_request_cancel_held.rpc_id(1)

func cancel_passenger_from_server(peer_id: int):
	if multiplayer.is_server() and mode == Mode.SHOOT and held_peer_id == peer_id:
		_server_end_mode()

func cancel():
	if multiplayer.is_server():
		_server_end_mode()

func _process(delta: float):
	super._process(delta)
	if multiplayer.has_multiplayer_peer() == false:
		return
	if not multiplayer.is_server():
		return

	if not _is_player_alive(owner_player):
		if mode != Mode.NORMAL:
			_server_end_mode()
		return

	if mode == Mode.PICKUP:
		_invite_update_timer -= delta
		if _invite_update_timer <= 0.0:
			_invite_update_timer = invite_update_interval
			_refresh_invited_peers()
	elif mode == Mode.SHOOT:
		if is_instance_valid(held_dummy):
			if not held_dummy.is_crew_shot_target_valid():
				_server_end_mode()
		else:
			var held_player := _get_player(held_peer_id)
			if not _is_player_alive(held_player) or not PlayerManager.is_same_team(
				owner_player.get_multiplayer_authority(),
				held_peer_id
			):
				_server_end_mode()

func _server_toggle(sender_id: int):
	if (
		not multiplayer.is_server()
		or not _is_cannoneer_request(sender_id)
		or not _is_player_available_for_pickup(owner_player)
		or is_on_cooldown
	):
		_request_pending = false
		_send_mode_to_owner()
		return

	match mode:
		Mode.NORMAL:
			_next_invitation_id += 1
			_invitation_id = _next_invitation_id
			_invited_peers.clear()
			_declined_peers.clear()
			_invite_update_timer = 0.0
			mode = Mode.PICKUP
			_refresh_invited_peers()
			_send_mode_to_owner()
		Mode.PICKUP, Mode.SHOOT:
			_server_end_mode()

func _refresh_invited_peers():
	var players_node := SceneManager.get_players_node()
	if not players_node:
		push_error("CrewShotAbility could not find World/Players")
		_server_end_mode()
		return

	var owner_peer_id := owner_player.get_multiplayer_authority()
	var owner_team := PlayerManager.get_team(owner_peer_id)
	if owner_team == PlayerManager.Team.NONE:
		_server_end_mode()
		return

	var eligible_peers: Dictionary = {}
	for candidate in players_node.get_children():
		if candidate == owner_player:
			continue
		var player := candidate as HeroBase
		if not _is_player_available_for_pickup(player):
			continue
		var peer_id := player.get_multiplayer_authority()
		if PlayerManager.get_team(peer_id) != owner_team:
			continue
		if player.global_position.distance_to(owner_player.global_position) > pickup_range:
			continue
		eligible_peers[peer_id] = true

	var ally_dummy := _get_nearby_ally_dummy()
	if ally_dummy:
		_clear_invites()
		_declined_peers.clear()
		held_peer_id = -1
		held_dummy = ally_dummy
		mode = Mode.SHOOT
		ally_dummy.set_crew_shot_held_from_server(
			owner_peer_id,
			true,
			Vector3.ZERO
		)
		_send_mode_to_owner()
		return

	for peer_id in _invited_peers.keys():
		if not eligible_peers.has(peer_id):
			_send_invite(peer_id, false)
			_invited_peers.erase(peer_id)

	for peer_id in _declined_peers.keys():
		if not eligible_peers.has(peer_id):
			_declined_peers.erase(peer_id)

	for peer_id in eligible_peers:
		if _invited_peers.has(peer_id) or _declined_peers.has(peer_id):
			continue
		_invited_peers[peer_id] = true
		_send_invite(peer_id, true)

func _server_accept(sender_id: int, invitation_id: int):
	if (
		not multiplayer.is_server()
		or mode != Mode.PICKUP
		or invitation_id != _invitation_id
		or not _invited_peers.has(sender_id)
	):
		return

	var player := _get_player(sender_id) as HeroBase
	if not _is_player_available_for_pickup(player):
		_send_invite(sender_id, false)
		_invited_peers.erase(sender_id)
		return
	if (
		PlayerManager.get_team(sender_id) == PlayerManager.Team.NONE
		or not PlayerManager.is_same_team(owner_player.get_multiplayer_authority(), sender_id)
	):
		_send_invite(sender_id, false)
		_invited_peers.erase(sender_id)
		return
	if player.global_position.distance_to(owner_player.global_position) > pickup_range:
		_send_invite(sender_id, false)
		_invited_peers.erase(sender_id)
		return

	_clear_invites()
	held_peer_id = sender_id
	held_dummy = null
	mode = Mode.SHOOT
	_set_player_held(player, true, Vector3.ZERO)
	_send_mode_to_owner()

func _server_decline(sender_id: int, invitation_id: int):
	if (
		not multiplayer.is_server()
		or mode != Mode.PICKUP
		or invitation_id != _invitation_id
		or not _invited_peers.has(sender_id)
	):
		return
	_invited_peers.erase(sender_id)
	_declined_peers[sender_id] = true
	_send_invite(sender_id, false)

func _server_cancel_held(sender_id: int):
	if not multiplayer.is_server() or mode != Mode.SHOOT or sender_id != held_peer_id:
		return
	_server_end_mode()

func _server_launch(sender_id: int, requested_direction: Vector3):
	if (
		not multiplayer.is_server()
		or mode != Mode.SHOOT
		or not _is_cannoneer_request(sender_id)
		or not _is_player_available_for_pickup(owner_player)
	):
		_request_pending = false
		_send_mode_to_owner()
		return
	if not requested_direction.is_finite() or requested_direction.length_squared() < 0.0001:
		_request_pending = false
		_send_mode_to_owner()
		return

	var camera := owner_player.get_node_or_null("Head/Camera3D") as Camera3D
	if not camera:
		push_error("CrewShotAbility could not find the Cannoneer's camera")
		_server_end_mode()
		return

	var direction := requested_direction.normalized()
	var current_aim := -camera.global_basis.z.normalized()
	if direction.dot(current_aim) < cos(deg_to_rad(max_aim_deviation_degrees)):
		_request_pending = false
		_send_mode_to_owner()
		return

	var target_is_alive := true
	if is_instance_valid(held_dummy):
		target_is_alive = held_dummy.health_component.health > 0
	else:
		target_is_alive = _is_player_alive(_get_player(held_peer_id))
	if not _is_player_alive(owner_player) or not target_is_alive:
		_server_end_mode()
		return

	var launch_velocity := direction * launch_speed + Vector3.UP * launch_lift
	_start_crew_shot_cooldown()
	_server_end_mode(launch_velocity)

func _start_crew_shot_cooldown() -> void:
	if not multiplayer.is_server() or not data or data.cooldown <= 0.0:
		return
	_start_cooldown()
	var owner_peer_id := owner_player.get_multiplayer_authority()
	if owner_peer_id != 1:
		_rpc_start_cooldown.rpc_id(owner_peer_id)

func _server_end_mode(launch_velocity: Vector3 = Vector3.ZERO):
	if not multiplayer.is_server():
		return
	if mode == Mode.NORMAL and _invited_peers.is_empty() and held_peer_id < 0:
		_request_pending = false
		return
	_clear_invites()
	_declined_peers.clear()

	if mode == Mode.SHOOT:
		if is_instance_valid(held_dummy):
			held_dummy.set_crew_shot_held_from_server(
				owner_player.get_multiplayer_authority(),
				false,
				launch_velocity
			)
		else:
			var held_player := _get_player(held_peer_id)
			if is_instance_valid(held_player):
				_set_player_held(held_player, false, launch_velocity)

	held_peer_id = -1
	held_dummy = null
	mode = Mode.NORMAL
	_request_pending = false
	_send_mode_to_owner()

func _clear_invites():
	for peer_id in _invited_peers.keys():
		_send_invite(peer_id, false)
	_invited_peers.clear()

func _send_invite(peer_id: int, show_invite: bool):
	var player := _get_player(peer_id)
	if not is_instance_valid(player):
		return
	if peer_id == 1:
		player.call(
			"set_crew_shot_invite_from_server",
			owner_player.get_multiplayer_authority(),
			_invitation_id,
			show_invite
		)
	else:
		player.rpc_id(
			peer_id,
			"_rpc_set_crew_shot_invite",
			owner_player.get_multiplayer_authority(),
			_invitation_id,
			show_invite
		)

func _set_player_held(player: Node, is_held: bool, launch_velocity: Vector3):
	var peer_id := player.get_multiplayer_authority()
	player.call(
		"set_crew_shot_held_from_server",
		owner_player.get_multiplayer_authority(),
		is_held,
		launch_velocity
	)
	if peer_id == 1:
		return
	else:
		player.rpc_id(
			peer_id,
			"_rpc_set_crew_shot_held",
			owner_player.get_multiplayer_authority(),
			is_held,
			launch_velocity
		)

func _send_mode_to_owner():
	var owner_peer_id := owner_player.get_multiplayer_authority()
	var target_name := ""
	if mode == Mode.SHOOT:
		target_name = (
			"Ally Practice Dummy"
			if is_instance_valid(held_dummy)
			else PlayerManager.get_player_name(held_peer_id)
		)
	if owner_peer_id == 1:
		_rpc_sync_mode(int(mode), held_peer_id, target_name)
	else:
		_rpc_sync_mode.rpc_id(owner_peer_id, int(mode), held_peer_id, target_name)

func _is_cannoneer_request(sender_id: int) -> bool:
	return is_instance_valid(owner_player) and sender_id == owner_player.get_multiplayer_authority()

func _is_player_alive(player: Node) -> bool:
	if not is_instance_valid(player) or not player is HeroBase:
		return false
	var health := player.get_node_or_null("PlayerHealth") as PlayerHealth
	return health != null and health.health > 0

func _is_player_available_for_pickup(player: HeroBase) -> bool:
	if not _is_player_alive(player):
		return false
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	return collision_shape != null and not collision_shape.disabled

func _get_player(peer_id: int) -> Node:
	var players_node := SceneManager.get_players_node()
	if players_node:
		return players_node.get_node_or_null(str(peer_id))
	return null

func _get_nearby_ally_dummy() -> PracticeDummy:
	for candidate in get_tree().get_nodes_in_group("practice_dummies"):
		var dummy := candidate as PracticeDummy
		if (
			dummy
			and dummy.can_accept_crew_shot()
			and dummy.global_position.distance_to(owner_player.global_position) <= pickup_range
		):
			return dummy
	return null

@rpc("any_peer", "call_remote", "reliable")
func _request_toggle():
	if multiplayer.is_server():
		_server_toggle(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func _request_accept(invitation_id: int):
	if multiplayer.is_server():
		_server_accept(multiplayer.get_remote_sender_id(), invitation_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_decline(invitation_id: int):
	if multiplayer.is_server():
		_server_decline(multiplayer.get_remote_sender_id(), invitation_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_cancel_held():
	if multiplayer.is_server():
		_server_cancel_held(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func _request_launch(direction: Vector3):
	if multiplayer.is_server():
		_server_launch(multiplayer.get_remote_sender_id(), direction)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_mode(new_mode: int, target_peer_id: int, target_name: String):
	if owner_player.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	mode = new_mode
	held_peer_id = target_peer_id
	_request_pending = false
	owner_player.crew_shot_speed_multiplier = (
		carrier_speed_multiplier if mode == Mode.SHOOT else 1.0
	)

	var hud := get_tree().get_first_node_in_group("UI")
	if not hud:
		return
	match mode:
		Mode.PICKUP:
			hud.call(
				"show_crew_shot_prompt",
				"PICKUP MODE  |  Teammates within " + str(pickup_range) + "m can accept  |  E: cancel"
			)
		Mode.SHOOT:
			hud.call(
				"show_crew_shot_prompt",
				"SHOOT MODE  |  LMB: launch " + target_name + "  |  E: release"
			)
		_:
			hud.call("hide_crew_shot_prompt")

@rpc("authority", "call_remote", "reliable")
func _rpc_start_cooldown():
	if owner_player.get_multiplayer_authority() == multiplayer.get_unique_id():
		_start_cooldown()
