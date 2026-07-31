extends CanvasLayer

const HERO_SELECT_DURATION: float = 20.0

var selected_index: int = 0
var players_ready: Dictionary = {}
var timer: float = HERO_SELECT_DURATION

@onready var hero_grid: GridContainer = $Panel/HeroGrid
@onready var timer_label: Label = $Panel/TimerLabel
@onready var confirm_button: Button = $Panel/ConfirmButton
@onready var ready_list: VBoxContainer = $Panel/ReadyList
@onready var hero_name_label: Label = $Panel/HeroName
@onready var hero_desc_label: Label = $Panel/HeroDescription

var game_flow_manager: GameFlowManager

func _ready():
	hide()
	confirm_button.pressed.connect(_on_confirm_pressed)
	# GameFlowManager signals here, connect when game flow triggers hero select

func show_hero_select(gfm: GameFlowManager):
	game_flow_manager = gfm
	reset_hero_select_overlay()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	players_ready.clear()
	timer = HERO_SELECT_DURATION
	_populate_heroes()
	_select_hero(0)
	
	if multiplayer.is_server():
		_countdown_loop()

func hide_hero_select():
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _populate_heroes():
	for child in hero_grid.get_children():
		child.queue_free()
	
	for i in PlayerManager.HEROES.size():
		var hero = PlayerManager.HEROES[i]
		var btn = Button.new()
		btn.text = hero.hero_name
		btn.pressed.connect(func(): _select_hero(i))
		hero_grid.add_child(btn)

func _select_hero(index: int):
	selected_index = index
	var hero = PlayerManager.HEROES[index]
	hero_name_label.text = hero.hero_name
	hero_desc_label.text = hero.hero_description

func _on_confirm_pressed():
	confirm_button.disabled = true
	if multiplayer.is_server():
		_confirm_selection(selected_index)
	else:
		_confirm_selection.rpc_id(1, selected_index)

func _countdown_loop():
	while timer > 0:
		await get_tree().create_timer(1.0).timeout
		if not visible:
			break
		timer -= 1.0
		_sync_timer.rpc(timer)
	if timer <= 0:
		_force_confirm_all()

func _force_confirm_all():
	for peer_id in PlayerManager.player_registry:
		if not players_ready.has(peer_id):
			players_ready[peer_id] = 0
	_apply_and_start()

func reset_hero_select_overlay() -> void:
	for child in ready_list.get_children():
		child.queue_free()
		confirm_button.disabled = false

@rpc("any_peer", "call_remote", "reliable")
func _confirm_selection(hero_index: int):
	var peer_id = multiplayer.get_remote_sender_id()
	players_ready[peer_id] = hero_index
	_sync_ready_state.rpc(players_ready)
	if players_ready.size() >= PlayerManager.player_registry.size():
		_apply_and_start()

func _apply_and_start():
	print("player ready ", players_ready)
	PlayerManager.set_hero_selections(players_ready)
	_sync_selections.rpc(players_ready)

@rpc("authority", "call_local", "reliable")
func _sync_selections(selections: Dictionary):
	PlayerManager.set_hero_selections(selections)
	hide_hero_select()
	var gfm = game_flow_manager
	if gfm and multiplayer.is_server():
		gfm.start_match()

@rpc("authority", "call_local", "reliable")
func _sync_ready_state(ready_dict: Dictionary):
	players_ready = ready_dict
	_refresh_ready_list()

@rpc("authority", "call_local", "unreliable")
func _sync_timer(time: float):
	timer = time
	timer_label.text = str(int(time)) + "s"

func _refresh_ready_list():
	for child in ready_list.get_children():
		child.queue_free()
	for peer_id in players_ready:
		var label = Label.new()
		var hero_name = PlayerManager.HEROES[players_ready[peer_id]].hero_name
		label.text = PlayerManager.get_player_name(peer_id) + " → " + hero_name
		ready_list.add_child(label)
