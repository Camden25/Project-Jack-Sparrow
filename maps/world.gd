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
	
	for i in range(PlayerManager.player_registry.size()):
		_on_player_connected(PlayerManager.player_registry.keys()[i])

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
	print("Spawning player object ", peer_id)
	var player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.spawn_position = respawn_manager.get_spawn_position(peer_id)
	print(peer_id, " position: ", player.spawn_position)
	players_node.add_child(player)
	return player

@rpc("authority", "call_remote", "reliable")
func _spawn_player_client(peer_id: int) -> void:
	print("spawning player object client ", peer_id)
	

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
