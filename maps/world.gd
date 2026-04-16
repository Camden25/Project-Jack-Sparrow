extends Node3D

@onready var players_node: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $Players/MultiplayerSpawner

const PLAYER_SCENE = preload("res://player/scenes/player.tscn")

var player_instances = []

func _ready() -> void:
	spawner.spawn_function = _spawn_player
	
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	
	for i in range(NetworkManager.players.size()):
		_on_player_connected(NetworkManager.players.keys()[i])

func _on_player_connected(peer_id: int):
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
	return player
