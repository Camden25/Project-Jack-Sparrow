extends Node
class_name RespawnManager

const RESPAWN_DELAY: float = 5.0

@onready var team_a_spawns: Node3D = $"../SpawnPoints/TeamA"
@onready var team_b_spawns: Node3D = $"../SpawnPoints/TeamB"

func get_spawn_position(peer_id: int) -> Vector3:
	var team = PlayerManager.get_team(peer_id)
	var spawns = team_a_spawns if team == PlayerManager.Team.TEAM_A else team_b_spawns
	var points = spawns.get_children()
	if points.is_empty():
		return Vector3.ZERO
	
	var spawn_position: Vector3 = points[randi() % points.size()].global_position
	print(peer_id, " get spawn position ", spawn_position)
	return spawn_position

func handle_player_death(peer_id: int):
	if not multiplayer.is_server():
		return
	
	var player = _get_player(peer_id)
	if player:
		print("player ", player, " disabled")
		_set_player_active.rpc(peer_id, false)
	
	_broadcast_death.rpc(peer_id)
	
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	respawn_player(peer_id)

func respawn_player(peer_id: int):
	if not multiplayer.is_server():
		return
	var spawn_pos = get_spawn_position(peer_id)
	var player = _get_player(peer_id)
	if not player:
		return
	
	player.health_component.set_health(player.health_component.MAX_HEALTH)
	_set_player_active.rpc(peer_id, true)
	
	player.global_position = spawn_pos
	
	if peer_id == 1:
		player.confirm_spawn(spawn_pos)
	else:
		var world = SceneManager.get_world()
		if world:
			world._set_client_spawn_position.rpc_id(peer_id, spawn_pos)

@rpc("authority", "call_local", "reliable")
func _broadcast_death(peer_id: int):
	print("Player died: " + str(peer_id))

@rpc("authority", "call_local", "reliable")
func _set_player_active(peer_id: int, active: bool):
	print("_set_player_active peer ", peer_id, " active ", active, " on ", multiplayer.get_unique_id())
	var player = _get_player(peer_id)
	print("player found: ", player != null)
	if not player:
		return
	player.set_active(active)

func _get_player(peer_id: int) -> Player:
	var players_node = SceneManager.get_players_node()
	if not players_node:
		return null
	return players_node.get_node_or_null(str(peer_id))
