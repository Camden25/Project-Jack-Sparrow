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
	# Pick random spawn point
	
	var spawn_position: Vector3 = points[randi() % points.size()].global_position
	print(peer_id, " get spawn position ", spawn_position)
	return spawn_position

func handle_player_death(peer_id: int):
	if not multiplayer.is_server():
		return
	
	# Disable player immediately
	var player = _get_player(peer_id)
	if player:
		_set_player_active.rpc(peer_id, false)
	
	# Notify all clients of death
	_broadcast_death.rpc(peer_id)
	
	# Start respawn timer
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	respawn_player(peer_id)

func respawn_player(peer_id: int):
	if not multiplayer.is_server():
		return
	var spawn_pos = get_spawn_position(peer_id)
	var player = _get_player(peer_id)
	if player:
		player.global_position = spawn_pos
		player.health_component.health = player.health_component.MAX_HEALTH
		player.health_component._sync_health.rpc(player.health_component.MAX_HEALTH)
		_set_player_active.rpc(peer_id, true)

@rpc("authority", "call_local", "reliable")
func _broadcast_death(peer_id: int):
	# clients can play death effects here
	print("Player died: " + str(peer_id))

@rpc("authority", "call_local", "reliable")
func _set_player_active(peer_id: int, active: bool):
	var player = _get_player(peer_id)
	if not player:
		return
	player.set_active(active)

func _get_player(peer_id: int) -> Player:
	var players_node = get_tree().get_root().get_node_or_null("World/Players")
	if not players_node:
		return null
	return players_node.get_node_or_null(str(peer_id))
