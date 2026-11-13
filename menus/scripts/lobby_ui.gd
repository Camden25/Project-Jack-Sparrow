extends Control

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var refresh_button: Button = $VBoxContainer/RefreshButton
@onready var practice_button: Button = $VBoxContainer/PracticeButton
@onready var invite_button: Button = $VBoxContainer/InviteButton
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var player_list: VBoxContainer = $VBoxContainer/PlayerList
@onready var switch_map_button: Button = $VBoxContainer/SwitchMap
@onready var map_label: Label = $VBoxContainer/SelectedMap
@onready var lobby_list: ItemList = $VBoxContainer/LobbyList
@onready var join_selected_button: Button = $VBoxContainer/JoinSelectedButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var settings_menu: SettingsMenu = $SettingsMenu

@export var available_maps: Array[String]
var selected_map_index: int = 0

func _ready():
	invite_button.hide()
	start_button.hide()
	
	# Network signals
	NetworkManager.lobby_created.connect(_on_lobby_created)
	NetworkManager.lobby_joined.connect(_on_lobby_joined)
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.lobby_join_failed.connect(_on_lobby_join_failed)
	NetworkManager.lobby_list_updated.connect(_on_lobby_match_list)
	
	# Button signals
	host_button.pressed.connect(_on_host_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	join_selected_button.pressed.connect(_on_join_selected_pressed)
	lobby_list.item_selected.connect(_on_lobby_selected)
	practice_button.pressed.connect(_on_practice_pressed)
	invite_button.pressed.connect(_on_invite_pressed)
	start_button.pressed.connect(_on_start_pressed)
	switch_map_button.pressed.connect(_on_switch_map_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_menu.return_pressed.connect(_on_settings_return_pressed)
	settings_menu.hide()
	
	status_label.text = "Not connected"
	join_selected_button.disabled = true
	
	PlayerManager.player_registered.connect(_on_player_registered)
	PlayerManager.team_assigned.connect(func(_id, _team): _refresh_player_list())
	
	if NetworkManager.steam_lobby_id != 0:
		_restore_lobby_state()

var _refresh_pending: bool = false

func _on_player_registered(_id: int):
	if _refresh_pending:
		return
	_refresh_pending = true
	_deferred_refresh()

func _deferred_refresh():
	await get_tree().create_timer(0.2).timeout
	_refresh_pending = false
	_refresh_player_list()

#region BUTTON HANDLERS

func _on_host_pressed():
	status_label.text = "Creating lobby..."
	print("HOST BUTTON PRESSED")
	host_button.disabled = true
	refresh_button.disabled = true
	practice_button.hide()
	NetworkManager.host_game()

func _on_refresh_pressed():
	status_label.text = "Searching..."
	refresh_button.disabled = true
	host_button.disabled = true
	join_selected_button.disabled = true
	lobby_list.clear()
	NetworkManager.request_lobby_list()

func _on_join_selected_pressed():
	var selected_items = lobby_list.get_selected_items()
	if selected_items.is_empty():
		return

	var lobby_id := int(lobby_list.get_item_metadata(selected_items[0]))
	status_label.text = "Joining lobby..."
	join_selected_button.disabled = true
	refresh_button.disabled = true
	host_button.disabled = true
	NetworkManager.join_game(lobby_id)

func _on_lobby_selected(_index: int):
	join_selected_button.disabled = false

func _on_practice_pressed():
	var error := NetworkManager.start_local_practice()
	if error != OK:
		status_label.text = "Could not start local practice: " + error_string(error)
		return

	SceneManager.goto_scene("res://maps/scenes/practice_range.tscn")

func _on_invite_pressed():
	Steam.activateGameOverlayInviteDialog(NetworkManager.steam_lobby_id)

func _on_start_pressed():
	start_game.rpc()

func _on_switch_map_pressed():
	selected_map_index += 1
	selected_map_index %= available_maps.size()
	map_label.text = "Map " + str(selected_map_index)

func _on_settings_pressed():
	settings_menu.show()

func _on_settings_return_pressed():
	settings_menu.hide()

#endregion


#region NETWORK CALLBACKS

func _on_lobby_created(_lobby_id: int):
	status_label.text = "Lobby created"
	host_button.hide()
	refresh_button.hide()
	lobby_list.hide()
	join_selected_button.hide()
	start_button.show()
	_refresh_player_list()

func _on_lobby_joined(_lobby_id: int):
	status_label.text = "Joined lobby"
	host_button.hide()
	refresh_button.hide()
	lobby_list.hide()
	join_selected_button.hide()
	_refresh_player_list()

func _on_player_connected(peer_id: int):
	status_label.text = "Player connected: " + str(peer_id)
	_refresh_player_list()

func _on_player_disconnected(_peer_id: int):
	_refresh_player_list()

func _on_server_disconnected():
	status_label.text = "Disconnected from server"
	_refresh_player_list()
	host_button.show()
	refresh_button.show()
	host_button.disabled = false
	refresh_button.disabled = false
	lobby_list.show()
	join_selected_button.show()
	invite_button.hide()
	start_button.hide()

func _on_lobby_match_list(lobbies: Array):
	lobby_list.clear()

	for lobby_id in lobbies:
		if Steam.getLobbyData(lobby_id, "state") != "lobby":
			continue

		var member_count = Steam.getNumLobbyMembers(lobby_id)
		var member_limit = Steam.getLobbyMemberLimit(lobby_id)
		if member_count >= member_limit:
			continue

		var lobby_name: String = Steam.getLobbyData(lobby_id, "name")
		if lobby_name.is_empty():
			lobby_name = "Lobby " + str(lobby_id)

		var index = lobby_list.add_item(lobby_name + " (" + str(member_count) + "/" + str(member_limit) + ")")
		lobby_list.set_item_metadata(index, lobby_id)

	host_button.disabled = false
	refresh_button.disabled = false

	if lobby_list.item_count == 0:
		status_label.text = "No open lobbies found"
	else:
		status_label.text = "Select a lobby to join"

	join_selected_button.disabled = true

func _on_lobby_join_failed(reason: String):
	status_label.text = reason
	host_button.disabled = false
	refresh_button.disabled = false
	join_selected_button.disabled = lobby_list.get_selected_items().is_empty()

#endregion


#region PLAYER LIST

func _refresh_player_list():
	for child in player_list.get_children():
		child.queue_free()
	
	for peer_id in PlayerManager.player_registry:
		var data = PlayerManager.player_registry[peer_id]
		print("rendering player: ", peer_id, " data: ", data)  # temp debug
		var label = Label.new()
		var team = PlayerManager.get_team(peer_id)
		var team_str = " [A]" if team == PlayerManager.Team.TEAM_A else " [B]" if team == PlayerManager.Team.TEAM_B else ""
		var display_name = data.get("name", "Unknown")
		label.text = display_name + team_str
		player_list.add_child(label)

#endregion


#region STARTING THE GAME

@rpc("authority", "call_local", "reliable")
func start_game():
	print("starting game")
	NetworkManager.set_game_state(NetworkManager.GameState.IN_GAME)
	#SceneManager.goto_scene("res://maps/world.tscn")
	SceneManager.goto_scene(available_maps[selected_map_index])

#endregion

func _restore_lobby_state():
	status_label.text = "Lobby"
	host_button.hide()
	refresh_button.hide()
	lobby_list.hide()
	join_selected_button.hide()
	
	if multiplayer.is_server():
		start_button.show()
	
	_refresh_player_list()
