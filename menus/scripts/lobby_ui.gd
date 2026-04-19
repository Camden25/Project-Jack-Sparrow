extends Control

# client:
# name doesnt update
# health not visible
# not resetting to spawn point
# no actual lag compensation

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var invite_button: Button = $VBoxContainer/InviteButton
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var player_list: VBoxContainer = $VBoxContainer/PlayerList

func _ready():
	invite_button.hide()
	start_button.hide()
	
	# Network signals
	NetworkManager.lobby_created.connect(_on_lobby_created)
	NetworkManager.lobby_joined.connect(_on_lobby_joined)
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	# Button signals
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	invite_button.pressed.connect(_on_invite_pressed)
	start_button.pressed.connect(_on_start_pressed)
	
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	
	status_label.text = "Not connected"


#region BUTTON HANDLERS

func _on_host_pressed():
	status_label.text = "Creating lobby..."
	print("HOST BUTTON PRESSED")
	host_button.disabled = true
	join_button.disabled = true
	NetworkManager.host_game()

func _on_join_pressed():
	status_label.text = "Searching..."
	join_button.disabled = true
	host_button.disabled = true
	#NetworkManager.join_game(109775242069591879)
	Steam.addRequestLobbyListStringFilter("game", "camden_projectjacksparrow", Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()

func _on_invite_pressed():
	Steam.activateGameOverlayInviteDialog(NetworkManager.steam_lobby_id)

func _on_start_pressed():
	start_game.rpc()

#endregion


#region NETWORK CALLBACKS

func _on_lobby_created(_lobby_id: int):
	status_label.text = "Lobby created"
	#invite_button.show()
	start_button.show()
	_refresh_player_list()

func _on_lobby_joined(_lobby_id: int):
	status_label.text = "Joined lobby"
	_refresh_player_list()

func _on_player_connected(peer_id: int):
	status_label.text = "Player connected: " + str(peer_id)
	_refresh_player_list()

func _on_player_disconnected(_peer_id: int):
	_refresh_player_list()

func _on_server_disconnected():
	status_label.text = "Disconnected from server"
	_refresh_player_list()
	host_button.disabled = false
	join_button.disabled = false
	invite_button.hide()
	start_button.hide()

func _on_lobby_match_list(lobbies: Array):
	if lobbies.is_empty():
		print("No lobbies found")
		host_button.disabled = false
		join_button.disabled = false
		invite_button.hide()
		start_button.hide()
		status_label.text = "No lobbies found"
		return
	
	var lobby_id = lobbies[0]
	Steam.joinLobby(lobby_id)

#endregion


#region PLAYER LIST

func _refresh_player_list():
	# Clear existing
	for child in player_list.get_children():
		child.queue_free()
	
	# Rebuild from NetworkManager.players
	for peer_id in PlayerManager.player_registry:
		var data = PlayerManager.player_registry[peer_id]
		var label = Label.new()
		label.text = str(data.get("name", "Unknown")) + " (" + str(peer_id) + ")"
		player_list.add_child(label)

#endregion


#region STARTING THE GAME

@rpc("authority", "call_local", "reliable")
func start_game():
	print("starting game")
	NetworkManager.set_game_state(NetworkManager.GameState.IN_GAME)
	get_tree().change_scene_to_file("res://maps/world.tscn")

#@rpc("any_peer", "call_remote", "reliable")
#func _notify_server_ready():
	#var peer_id = multiplayer.get_remote_sender_id()
	#var world = get_tree().get_root().get_node_or_null("World")
	#if world:
		#world._spawn_player(peer_id)
		#var spawn_pos = world.respawn_manager.get_spawn_position(peer_id)
		#world._set_client_spawn_position.rpc_id(peer_id, spawn_pos)

#endregion
