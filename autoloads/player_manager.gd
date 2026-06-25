extends Node

enum Team { NONE = -1, TEAM_A = 0, TEAM_B = 1 }

# peer_id: { steam_id, name, team }
var player_registry: Dictionary = {}

const HEROES: Array = [
	preload("res://heroes/resources/ex_navy_officer_data.tres"),
]

signal player_registered(peer_id: int)
signal team_assigned(peer_id: int, team: Team)

func register_player(peer_id: int, steam_id: int, player_name: String):
	player_registry[peer_id] = {
		"steam_id": steam_id,
		"name": player_name,
		"team": Team.NONE
	}
	emit_signal("player_registered", peer_id)
	
	if multiplayer.is_server():
		_auto_assign_team(peer_id)

func _auto_assign_team(peer_id: int):
	# Balance teams — count current members
	var team_a = get_team_members(Team.TEAM_A).size()
	var team_b = get_team_members(Team.TEAM_B).size()
	var team = Team.TEAM_A if team_a <= team_b else Team.TEAM_B
	assign_team(peer_id, team)

func assign_team(peer_id: int, team: Team):
	if not player_registry.has(peer_id):
		return
	player_registry[peer_id].team = team
	_sync_team.rpc(peer_id, team)
	emit_signal("team_assigned", peer_id, team)

@rpc("authority", "call_local", "reliable")
func _sync_team(peer_id: int, team: int):
	if player_registry.has(peer_id):
		player_registry[peer_id].team = team
	emit_signal("team_assigned", peer_id, team)

func get_team(peer_id: int) -> Team:
	if not player_registry.has(peer_id):
		return Team.NONE
	return player_registry[peer_id].team

func get_team_members(team: Team) -> Array:
	var members = []
	for pid in player_registry:
		if player_registry[pid].team == team:
			members.append(pid)
	return members

func get_player_name(peer_id: int) -> String:
	if not player_registry.has(peer_id):
		return "Unknown"
	return player_registry[peer_id].name

func unregister_player(peer_id: int):
	player_registry.erase(peer_id)

func is_same_team(peer_a: int, peer_b: int) -> bool:
	return get_team(peer_a) == get_team(peer_b)
