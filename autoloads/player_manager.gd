extends Node

enum Team { NONE = -1, TEAM_A = 0, TEAM_B = 1 }

var player_registry: Dictionary = {} # peer_id: { steam_id, name, team }

const HEROES: Array = [
	preload("res://heroes/resources/ex_navy_officer_data.tres"),
	preload("res://heroes/resources/octopus_in_a_barrel.tres")
]

var hero_selections: Dictionary = {} # peer_id: hero_index

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

func set_hero_selections(selections: Dictionary):
	hero_selections = selections

func get_hero_for_peer(peer_id: int) -> HeroData:
	if HEROES.is_empty():
		return null
	print(hero_selections)
	print(peer_id)
	var index = hero_selections.get(peer_id, 0)
	if peer_id == 1:
		print("peer id is local so getting id 0")
		index = hero_selections.get(0, 0)
	print(index)
	index = clamp(index, 0, HEROES.size() - 1)
	return HEROES[index]
