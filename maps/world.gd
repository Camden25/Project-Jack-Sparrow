extends Node3D

@onready var players_node: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $Players/MultiplayerSpawner
@onready var respawn_manager: RespawnManager = $RespawnManager

@onready var projectile_events: ProjectileEventService = $ProjectileEvents

var player_instances = []
var _hero_select_complete: bool = false

func _ready() -> void:
	spawner.spawn_function = _spawn_player
	
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

func spawn_all_players():
	_hero_select_complete = true
	if multiplayer.is_server():
		for peer_id in PlayerManager.player_registry.keys():
			_spawn_player(peer_id)

func _on_player_connected(peer_id: int):
	print("_on_player_connected ran with id ", peer_id)
	if multiplayer.is_server() and _hero_select_complete:
		_spawn_player(peer_id)

func _on_player_disconnected(peer_id: int):
	if multiplayer.is_server():
		var player = players_node.get_node_or_null(str(peer_id))
		if player:
			player.queue_free()

func _spawn_player(peer_id: int) -> Node:
	var hero_data = PlayerManager.get_hero_for_peer(peer_id)
	print(hero_data.hero_name)
	var scene = hero_data.hero_scene if hero_data else preload("res://player/scenes/player.tscn")
	
	var player = scene.instantiate()
	player.name = str(peer_id)
	players_node.add_child(player, true)
	
	var spawn_pos = respawn_manager.get_spawn_position(peer_id)
	player.global_position = spawn_pos
	
	if peer_id == 1:
		player.confirm_spawn(spawn_pos)
	else:
		_delayed_spawn_confirm(peer_id, spawn_pos)
	
	if multiplayer.is_server():
		player.health_component.player_died.connect(
			func(died_peer_id): respawn_manager.handle_player_death(died_peer_id)
		)
	
	return player

func _delayed_spawn_confirm(peer_id: int, spawn_pos: Vector3):
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("sending spawn confirm to peer ", peer_id, " pos ", spawn_pos)
	_set_client_spawn_position.rpc_id(peer_id, spawn_pos)

@rpc("authority", "call_remote", "reliable")
func _set_client_spawn_position(spawn_pos: Vector3):
	print("_set_client_spawn_position received on ", multiplayer.get_unique_id(), " pos ", spawn_pos)
	var my_id = str(multiplayer.get_unique_id())
	var player = players_node.get_node_or_null(my_id)
	print("player found: ", player != null)
	if player:
		if player.spawn_confirmed:
			player.confirm_respawn(spawn_pos)
		else:
			player.confirm_spawn(spawn_pos)
	else:
		await get_tree().process_frame
		await get_tree().process_frame
		player = players_node.get_node_or_null(my_id)
		print("player found after wait: ", player != null)
		if player:
			player.confirm_spawn(spawn_pos)
		else:
			push_error("Could not find player node for peer " + str(multiplayer.get_unique_id()))

func spawn_projectile(key: String, data: Dictionary) -> int:
	if not multiplayer.is_server():
		push_error("Only the server can spawn gameplay projectiles")
		return -1
	return projectile_events.spawn_authoritative(key, data)
