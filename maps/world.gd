extends Node3D

@onready var players_node: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $Players/MultiplayerSpawner
@onready var respawn_manager: RespawnManager = $RespawnManager

@onready var projectiles_node: Node3D = $Projectiles
@onready var projectiles_spawner: MultiplayerSpawner = $Projectiles/MultiplayerSpawner

const PLAYER_SCENE = preload("res://player/scenes/player.tscn")

var player_instances = []

func _ready() -> void:
	spawner.spawn_function = _spawn_player
	projectiles_spawner.spawn_function = _spawn_tracer_func
	
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	
	if multiplayer.is_server():
		for peer_id in PlayerManager.player_registry.keys():
			_spawn_player(peer_id)

func _on_player_connected(peer_id: int):
	print("_on_player_connected ran with id ", peer_id)
	if multiplayer.is_server():
		_spawn_player(peer_id)

func _on_player_disconnected(peer_id: int):
	if multiplayer.is_server():
		var player = players_node.get_node_or_null(str(peer_id))
		if player:
			player.queue_free()

func _spawn_player(peer_id: int) -> Node:
	var player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	players_node.add_child(player)
	
	var spawn_pos = respawn_manager.get_spawn_position(peer_id)
	player.global_position = spawn_pos
	
	if peer_id == 1:
		player.confirm_spawn(spawn_pos)
	else:
		_delayed_spawn_confirm(peer_id, spawn_pos)
	
	return player

func _delayed_spawn_confirm(peer_id: int, spawn_pos: Vector3):
	await get_tree().process_frame
	await get_tree().process_frame
	_set_client_spawn_position.rpc_id(peer_id, spawn_pos)

@rpc("authority", "call_remote", "reliable")
func _set_client_spawn_position(spawn_pos: Vector3):
	var my_id = str(multiplayer.get_unique_id())
	var player = players_node.get_node_or_null(my_id)
	if player:
		if player.spawn_confirmed:
			player.confirm_respawn(spawn_pos)
		else:
			player.confirm_spawn(spawn_pos)
	else:
		await get_tree().process_frame
		player = players_node.get_node_or_null(my_id)
		if player:
			player.confirm_spawn(spawn_pos)

func spawn_tracer(origin: Vector3, direction: Vector3):
	if not multiplayer.is_server():
		return
	projectiles_spawner.spawn({ "origin": origin, "direction": direction })

func _spawn_tracer_func(data: Dictionary) -> Node:
	var tracer = preload("res://weapons/scenes/tracer.tscn").instantiate()
	tracer.name = "Tracer_" + str(Time.get_ticks_msec())
	tracer.start_pos = data.origin
	tracer.direction = data.direction
	return tracer
