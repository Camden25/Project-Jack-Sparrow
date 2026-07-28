extends Node
class_name GameFlowManager

enum State { WAITING, HERO_SELECT, COUNTDOWN, ACTIVE, ROUND_END, MATCH_END }

const COUNTDOWN_DURATION: float = 5.0
const ROUND_END_DURATION: float = 5.0
const HERO_SELECT_DURATION: float = 20.0

var state: State = State.WAITING
var current_mode: GameMode = null

signal state_changed(new_state: State)

func _ready():
	if not multiplayer.is_server():
		return
	
	# Find and connect game mode node
	current_mode = get_node_or_null("ControlPointMode")
	if current_mode:
		GameModeEvents.connect_to_mode(current_mode)
		current_mode.round_ended.connect(_on_round_ended)
	
	_begin_hero_select()

func _begin_hero_select():
	_sync_show_hero_select.rpc()

@rpc("authority", "call_local", "reliable")
func _sync_show_hero_select():
	var overlay = get_tree().get_root().get_node_or_null("Root/PersistentUI/HeroSelectOverlay")
	if overlay:
		overlay.show_hero_select(self)  # pass GameFlowManager so overlay can call start_match

func _go_to_hero_select():
	_sync_state.rpc(State.HERO_SELECT)
	_show_hero_select.rpc()

@rpc("authority", "call_local", "reliable")
func _show_hero_select():
	var overlay = get_tree().get_root().get_node_or_null("Root/PersistentUI/HeroSelectOverlay")
	if overlay:
		overlay.show_hero_select()

@rpc("authority", "call_local", "reliable")
func _hide_hero_select():
	var overlay = get_tree().get_root().get_node_or_null("Root/PersistentUI/HeroSelectOverlay")
	if overlay:
		overlay.hide_hero_select()

func start_match():
	if not multiplayer.is_server():
		return
	
	var world = SceneManager.get_world()
	if world:
		world.spawn_all_players()
	
	_start_countdown()

func _start_countdown():
	_sync_state.rpc(State.COUNTDOWN)
	await get_tree().create_timer(COUNTDOWN_DURATION).timeout
	_start_round()

func _start_round():
	_sync_state.rpc(State.ACTIVE)
	if current_mode:
		current_mode.start_round()

func _on_round_ended(winning_team: int):
	_sync_state.rpc(State.ROUND_END)
	await get_tree().create_timer(ROUND_END_DURATION).timeout
	# Show hero select again for next round
	_begin_hero_select()

@rpc("authority", "call_local", "reliable")
func _sync_state(new_state: int):
	state = new_state as State
	emit_signal("state_changed", state)
