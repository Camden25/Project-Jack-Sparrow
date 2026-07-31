extends Node

const DEFAULT_PORT = 7777
const MAX_PLAYERS = 6

var steam_lobby_id: int = 0

var peer_pings: Dictionary = {}  # peer_id: ping_seconds
var _ping_timestamps: Dictionary = {}  # peer_id: send_time

enum GameState { LOBBY, IN_GAME }
var game_state: GameState = GameState.LOBBY

var is_host: bool = false

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)

func _ready():
	var init = Steam.steamInitEx()
	if init.status != Steam.STEAM_API_INIT_RESULT_OK:
		push_error("Steam failed to initialize: " + str(init.verbal))
		return
	
	Steam.initRelayNetworkAccess()
	
	print("Steam running:", Steam.isSteamRunning())
	print("Steam ID:", Steam.getSteamID())
	print("Persona:", Steam.getPersonaName())
	
	print("Steam init:", init.status)
	print("Steam connected:", Steam.isSteamRunning())
	print("Steam universe:", Steam.getConnectedUniverse())
	
	multiplayer.connected_to_server.connect(func():
		print("CONNECTED TO SERVER OK")
	)

	multiplayer.connection_failed.connect(func():
		print("CONNECTION FAILED")
	)

	multiplayer.server_disconnected.connect(func():
		print("SERVER DISCONNECTED")
	)
	
	# Multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Steam signals
	Steam.lobby_created.connect(_on_steam_lobby_created)
	Steam.lobby_joined.connect(_on_steam_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.p2p_session_request.connect(_on_p2p_session_request)
	
	if multiplayer.is_server():
		_ping_loop()

func _process(_delta):
	Steam.run_callbacks()


#region HOSTING

func host_game():
	print("Network Manager: host_game")
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_PLAYERS)

func _on_steam_lobby_created(result: int, lobby_id: int):
	print("LOBBY CREATED CALLBACK FIRED: ", result, " ", lobby_id)
	
	if result != Steam.RESULT_OK:
		push_error("Lobby failed")
		return
	
	steam_lobby_id = lobby_id
	
	# IMPORTANT: set lobby metadata so others know game type
	Steam.setLobbyData(lobby_id, "game", "camden_projectjacksparrow")
	
	# NOW create peer
	var peer = SteamMultiplayerPeer.new()
	var err = peer.create_host(0)
	
	if err != OK:
		push_error("Host peer failed: " + str(err))
		return
	
	multiplayer.multiplayer_peer = peer
	
	is_host = true
	
	PlayerManager.register_player(1, Steam.getSteamID(), Steam.getPersonaName())
	
	print("Host ready")
	
	emit_signal("lobby_created", lobby_id)

#endregion


#region JOINING

func join_game(lobby_id: int):
	Steam.joinLobby(lobby_id)

func _on_steam_lobby_joined(lobby_id: int, _p, _l, response: int):
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		push_error("Lobby join failed")
		return
	
	if is_host:
		print("Ignoring lobby_joined on host")
		return
	
	steam_lobby_id = lobby_id
	
	await get_tree().process_frame
	
	var host_id = Steam.getLobbyOwner(lobby_id)
	
	if host_id == 0:
		push_error("Invalid host")
		return
	
	var peer = SteamMultiplayerPeer.new()
	var err = peer.create_client(host_id, 0)
	
	if err != OK:
		push_error("Client failed: " + str(err))
		return
	
	multiplayer.multiplayer_peer = peer
	
	_register_player(Steam.getSteamID(), Steam.getPersonaName())
	
	print("Client connected to host")
	
	emit_signal("lobby_joined", lobby_id)

#endregion


#region DEDICATED SERVER (headless)

func start_dedicated_server():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	print("Dedicated server started on port " + str(DEFAULT_PORT))

func join_dedicated_server(ip: String, port: int = DEFAULT_PORT):
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer

#endregion


#region PEER CALLBACKS

func _on_peer_connected(peer_id: int):
	print("Peer connected: " + str(peer_id))
	emit_signal("player_connected", peer_id)
	
	if multiplayer.is_server():
		for existing_id in PlayerManager.player_registry:
			var data = PlayerManager.player_registry[existing_id]
			_sync_existing_player.rpc_id(peer_id, existing_id, data.steam_id, data.name)
		
		if game_state == GameState.IN_GAME:
			_redirect_to_game.rpc_id(peer_id)

@rpc("authority", "call_remote", "reliable")
func _sync_existing_player(existing_peer_id: int, steam_id: int, player_name: String):
	PlayerManager.register_player(existing_peer_id, steam_id, player_name)

func _on_peer_disconnected(peer_id: int):
	PlayerManager.unregister_player(peer_id)
	emit_signal("player_disconnected", peer_id)

func _on_connected_to_server():
	print("Connected to server successfully")
	var my_id = multiplayer.get_unique_id()
	PlayerManager.register_player(my_id, Steam.getSteamID(), Steam.getPersonaName())
	_register_player.rpc_id(1, Steam.getSteamID(), Steam.getPersonaName())

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	emit_signal("server_disconnected")

func _on_p2p_session_request(remote_steam_id: int):
	print("P2P SESSION REQUEST FROM:", remote_steam_id)
	Steam.acceptP2PSessionWithUser(remote_steam_id)

#endregion


#region UTILITIES

@rpc("any_peer", "call_remote", "reliable")
func _register_player(steam_id: int, player_name: String):
	var sender_id = multiplayer.get_remote_sender_id()
	PlayerManager.register_player(sender_id, steam_id, player_name)

func is_server() -> bool:
	return multiplayer.is_server()

func get_my_peer_id() -> int:
	return multiplayer.get_unique_id()

func disconnect_game():
	if steam_lobby_id != 0:
		Steam.leaveLobby(steam_lobby_id)
	multiplayer.multiplayer_peer = null
	steam_lobby_id = 0
	PlayerManager.player_registry.clear()

func _on_lobby_match_list(lobbies: Array):
	for lobby_id in lobbies:
		var _lobby_name = Steam.getLobbyData(lobby_id, "game")
		var _owner = Steam.getLobbyOwner(lobby_id)
		var members = Steam.getNumLobbyMembers(lobby_id)
		print("Lobby: " + str(lobby_id) + " owner: " + str(_owner) + " players: " + str(members))

func set_game_state(state: GameState):
	game_state = state

@rpc("authority", "call_remote", "reliable")
func _redirect_to_game():
	await SceneManager.goto_scene("res://maps/world.tscn")
	_client_ready_in_world.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _client_ready_in_world():
	var peer_id = multiplayer.get_remote_sender_id()
	var gfm = SceneManager.get_world().get_node_or_null("GameFlowManager") if SceneManager.get_world() else null
	if not gfm:
		return
	
	match gfm.state:
		GameFlowManager.State.HERO_SELECT:
			# Show hero select for this player only
			_show_hero_select_for_peer.rpc_id(peer_id)
		GameFlowManager.State.ACTIVE, GameFlowManager.State.COUNTDOWN:
			# Assign default hero and spawn immediately
			PlayerManager.hero_selections[peer_id] = 0
			var world = SceneManager.get_world()
			if world:
				world._spawn_player(peer_id)
				var spawn_pos = world.respawn_manager.get_spawn_position(peer_id)
				world._set_client_spawn_position.rpc_id(peer_id, spawn_pos)

@rpc("authority", "call_remote", "reliable")
func _show_hero_select_for_peer():
	var overlay = get_tree().get_root().get_node_or_null("Root/PersistentUI/HeroSelectOverlay")
	if overlay:
		overlay.show_hero_select(SceneManager.get_world().get_node_or_null("GameFlowManager"))

func return_to_lobby():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	PlayerManager.hero_selections.clear()
	set_game_state(GameState.LOBBY)
	SceneManager.goto_scene("res://menus/scenes/lobby_ui.tscn")
	
	if multiplayer.is_server():
		PlayerManager.player_registry.clear()
		PlayerManager.register_player(1, Steam.getSteamID(), Steam.getPersonaName())
		_request_reregistration.rpc()

@rpc("authority", "call_remote", "reliable")
func _request_reregistration():
	# Client re-sends their info to server
	var my_id = multiplayer.get_unique_id()
	PlayerManager.player_registry.clear()
	PlayerManager.register_player(my_id, Steam.getSteamID(), Steam.getPersonaName())
	_register_player.rpc_id(1, Steam.getSteamID(), Steam.getPersonaName())

#endregion


#region PING
func _ping_loop():
	while true:
		await get_tree().create_timer(1.0).timeout
		if not multiplayer.is_server():
			break
		for peer_id in PlayerManager.player_registry.keys():
			if peer_id == 1:
				peer_pings[1] = 0.0
				continue
			_ping_timestamps[peer_id] = Time.get_ticks_msec() / 1000.0
			_send_ping.rpc_id(peer_id)

@rpc("authority", "call_remote", "reliable")
func _send_ping():
	_pong.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _pong():
	var sender_id = multiplayer.get_remote_sender_id()
	if _ping_timestamps.has(sender_id):
		var rtt = (Time.get_ticks_msec() / 1000.0) - _ping_timestamps[sender_id]
		peer_pings[sender_id] = rtt / 2.0  # one-way latency
		_ping_timestamps.erase(sender_id)

func get_peer_ping(peer_id: int) -> float:
	return peer_pings.get(peer_id, 0.05)  # default 50ms if unknown
#endregion
