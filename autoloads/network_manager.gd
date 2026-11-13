extends Node

const DEFAULT_PORT = 7777
const MAX_PLAYERS = 8
const GAME_LOBBY_KEY = "game"
const LOBBY_NAME_KEY = "name"
const LOBBY_STATE_KEY = "state"
const LOBBY_STATE_OPEN = "lobby"
const LOBBY_STATE_IN_GAME = "in_game"

var steam_lobby_id: int = 0
var steam_initialized: bool = false
var _steam_callbacks_embedded: bool = false
var _steam_init_failure_reason: String = ""

var peer_pings: Dictionary = {}  # peer_id: ping_seconds
var _ping_timestamps: Dictionary = {}  # peer_id: send_time
var _world_ready_peers: Dictionary = {}
var _acknowledged_world_ready_token: int = 0

enum GameState { LOBBY, IN_GAME }
var game_state: GameState = GameState.LOBBY

var is_host: bool = false

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_join_failed(reason: String)
signal lobby_list_updated(lobbies: Array)

func _ready():
	var app_id := int(ProjectSettings.get_setting("steam/initialization/app_id", 0))
	_steam_callbacks_embedded = bool(
		ProjectSettings.get_setting("steam/initialization/embed_callbacks", false)
	)
	var init: Dictionary = Steam.steamInitEx(app_id, _steam_callbacks_embedded)
	var init_status := int(init.get("status", -1))
	if init_status != Steam.STEAM_API_INIT_RESULT_OK:
		_steam_init_failure_reason = (
			"Steam failed to initialize for App ID %d (status %d): %s"
			% [app_id, init_status, str(init.get("verbal", "No failure details returned."))]
		)
		push_error(_steam_init_failure_reason)
		return
	
	steam_initialized = true
	print("Steam initialized with App ID: ", app_id)
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
	if steam_initialized and not _steam_callbacks_embedded:
		Steam.run_callbacks()


#region HOSTING

func host_game():
	print("Network Manager: host_game")
	if not _require_steam("create a lobby"):
		return
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_PLAYERS)

func _on_steam_lobby_created(result: int, lobby_id: int):
	print("LOBBY CREATED CALLBACK FIRED: ", result, " ", lobby_id)
	
	if result != Steam.RESULT_OK:
		push_error("Lobby failed")
		lobby_join_failed.emit("Could not create a lobby.")
		return
	
	steam_lobby_id = lobby_id
	
	Steam.setLobbyData(lobby_id, GAME_LOBBY_KEY, "camden_projectjacksparrow")
	Steam.setLobbyData(lobby_id, LOBBY_NAME_KEY, Steam.getPersonaName() + "'s lobby")
	Steam.setLobbyData(lobby_id, LOBBY_STATE_KEY, LOBBY_STATE_OPEN)
	Steam.setLobbyJoinable(lobby_id, true)
	
	# NOW create peer
	var peer = SteamMultiplayerPeer.new()
	var err = peer.create_host(0)
	
	if err != OK:
		push_error("Host peer failed: " + str(err))
		Steam.leaveLobby(lobby_id)
		steam_lobby_id = 0
		lobby_join_failed.emit("Could not start hosting the lobby.")
		return
	
	multiplayer.multiplayer_peer = peer
	
	is_host = true
	
	PlayerManager.register_player(1, Steam.getSteamID(), Steam.getPersonaName())
	
	print("Host ready")
	
	emit_signal("lobby_created", lobby_id)

#endregion


#region JOINING

func join_game(lobby_id: int):
	if not _require_steam("join a lobby"):
		return
	Steam.joinLobby(lobby_id)

func _on_steam_lobby_joined(lobby_id: int, _p, _l, response: int):
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		push_error("Lobby join failed")
		lobby_join_failed.emit("Could not join that lobby.")
		return
	
	if is_host:
		print("Ignoring lobby_joined on host")
		return
	
	if Steam.getLobbyData(lobby_id, LOBBY_STATE_KEY) == LOBBY_STATE_IN_GAME:
		Steam.leaveLobby(lobby_id)
		steam_lobby_id = 0
		lobby_join_failed.emit("That match is already in progress.")
		return
	
	steam_lobby_id = lobby_id
	
	await get_tree().process_frame
	
	var host_id = Steam.getLobbyOwner(lobby_id)
	
	if host_id == 0:
		push_error("Invalid host")
		Steam.leaveLobby(lobby_id)
		steam_lobby_id = 0
		lobby_join_failed.emit("Could not find the lobby host.")
		return
	
	var peer = SteamMultiplayerPeer.new()
	var err = peer.create_client(host_id, 0)
	
	if err != OK:
		push_error("Client failed: " + str(err))
		Steam.leaveLobby(lobby_id)
		steam_lobby_id = 0
		lobby_join_failed.emit("Could not connect to the lobby host.")
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
	
	if multiplayer.is_server() and game_state == GameState.IN_GAME:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id, true)
		return
	
	emit_signal("player_connected", peer_id)
	
	if multiplayer.is_server():
		for existing_id in PlayerManager.player_registry:
			var data = PlayerManager.player_registry[existing_id]
			_sync_existing_player.rpc_id(peer_id, existing_id, data.steam_id, data.name)
		

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
	if steam_lobby_id != 0:
		Steam.leaveLobby(steam_lobby_id)
	steam_lobby_id = 0
	multiplayer.multiplayer_peer = null
	is_host = false
	game_state = GameState.LOBBY
	PlayerManager.player_registry.clear()
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
	is_host = false
	set_game_state(GameState.LOBBY)
	PlayerManager.player_registry.clear()

func start_local_practice() -> Error:
	disconnect_game()
	
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(0, 1)
	if error != OK:
		push_error("Could not start local practice server: " + error_string(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	set_game_state(GameState.IN_GAME)
	PlayerManager.register_player(1, 0, "Local Player")
	return OK

func _on_lobby_match_list(lobbies: Array):
	for lobby_id in lobbies:
		var _lobby_name = Steam.getLobbyData(lobby_id, "game")
		var members = Steam.getNumLobbyMembers(lobby_id)
		print("Lobby: " + str(lobby_id) + " players: " + str(members))
	lobby_list_updated.emit(lobbies)

func request_lobby_list():
	if not _require_steam("search for lobbies"):
		return
	Steam.addRequestLobbyListStringFilter(GAME_LOBBY_KEY, "camden_projectjacksparrow", Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListStringFilter(LOBBY_STATE_KEY, LOBBY_STATE_OPEN, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()

func _require_steam(operation: String) -> bool:
	if steam_initialized:
		return true

	var init_reason := _steam_init_failure_reason
	if init_reason.is_empty():
		init_reason = "Steam initialization has not completed."
	var reason := "Cannot %s. %s" % [operation, init_reason]
	push_warning(reason)
	lobby_join_failed.emit(reason)
	return false

func set_game_state(state: GameState):
	game_state = state
	if is_host and steam_lobby_id != 0:
		var lobby_state = LOBBY_STATE_IN_GAME if state == GameState.IN_GAME else LOBBY_STATE_OPEN
		Steam.setLobbyData(steam_lobby_id, LOBBY_STATE_KEY, lobby_state)
		Steam.setLobbyJoinable(steam_lobby_id, state == GameState.LOBBY)

@rpc("any_peer", "call_remote", "reliable")
func _client_ready_in_world(world_ready_token: int):
	var peer_id = multiplayer.get_remote_sender_id()
	if _world_ready_peers.get(peer_id, 0) == world_ready_token:
		_acknowledge_client_world_ready.rpc_id(peer_id, world_ready_token)
		return

	var gfm = SceneManager.get_world().get_node_or_null("GameFlowManager") if SceneManager.get_world() else null
	if not gfm:
		return
	
	_world_ready_peers[peer_id] = world_ready_token
	gfm._sync_state.rpc_id(peer_id, gfm.state)
	match gfm.state:
		GameFlowManager.State.HERO_SELECT:
			_show_hero_select_for_peer.rpc_id(peer_id)
		GameFlowManager.State.ACTIVE, GameFlowManager.State.COUNTDOWN:
			PlayerManager.hero_selections[peer_id] = 0
			var world = SceneManager.get_world()
			if world:
				world._spawn_player(peer_id)
	_acknowledge_client_world_ready.rpc_id(peer_id, world_ready_token)

@rpc("authority", "call_remote", "reliable")
func _acknowledge_client_world_ready(world_ready_token: int):
	_acknowledged_world_ready_token = world_ready_token

@rpc("authority", "call_remote", "reliable")
func _show_hero_select_for_peer():
	var overlay = get_tree().get_root().get_node_or_null("Root/PersistentUI/HeroSelectOverlay")
	var world = SceneManager.get_world()
	var gfm = world.get_node_or_null("GameFlowManager") if world else null
	if overlay and gfm:
		overlay.show_hero_select(gfm)

func return_to_main_menu():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	disconnect_game()
	PlayerManager.hero_selections.clear()
	peer_pings.clear()
	_ping_timestamps.clear()
	_world_ready_peers.clear()
	_acknowledged_world_ready_token = 0
	SceneManager.goto_scene("res://menus/scenes/lobby_ui.tscn")

@rpc("authority", "call_remote", "reliable")
func _return_clients_to_main_menu():
	return_to_main_menu()

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
		if multiplayer.has_multiplayer_peer() == false:
			break
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
		_sync_local_ping.rpc_id(sender_id, peer_pings[sender_id])

@rpc("authority", "call_remote", "reliable")
func _sync_local_ping(ping_seconds: float):
	if multiplayer.is_server():
		return
	peer_pings[multiplayer.get_unique_id()] = ping_seconds

func get_peer_ping(peer_id: int) -> float:
	return peer_pings.get(peer_id, 0.05)  # default 50ms if unknown
#endregion
