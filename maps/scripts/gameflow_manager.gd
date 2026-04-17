extends Node

enum State { WAITING, COUNTDOWN, ACTIVE, ROUND_END }

const KILLS_TO_WIN: int = 10
const COUNTDOWN_DURATION: float = 5.0
const ROUND_END_DURATION: float = 5.0

var state: State = State.WAITING
var scores: Dictionary = { 0: 0, 1: 0 }  # team: kills

signal state_changed(new_state: State)
signal score_updated(team: int, kills: int)
signal round_ended(winning_team: int)

func _ready():
	if not multiplayer.is_server():
		return
	MatchEvents.player_killed.connect(_on_player_killed)
	PlayerManager.player_registered.connect(_check_start_conditions)

func _check_start_conditions(_peer_id: int):
	if state != State.WAITING:
		return
	# Start when both teams have at least 1 player
	var team_a = PlayerManager.get_team_members(PlayerManager.Team.TEAM_A).size()
	var team_b = PlayerManager.get_team_members(PlayerManager.Team.TEAM_B).size()
	if team_a >= 1 and team_b >= 1:
		_start_countdown()

func _start_countdown():
	_sync_state.rpc(State.COUNTDOWN)
	await get_tree().create_timer(COUNTDOWN_DURATION).timeout
	_start_round()

func _start_round():
	scores = { 0: 0, 1: 0 }
	_sync_state.rpc(State.ACTIVE)
	_sync_scores.rpc(scores)

func _on_player_killed(killer_id: int, _victim_id: int):
	if state != State.ACTIVE:
		return
	var team = PlayerManager.get_team(killer_id)
	scores[team] += 1
	_sync_scores.rpc(scores)
	if scores[team] >= KILLS_TO_WIN:
		_end_round(team)

func _end_round(winning_team: int):
	_sync_state.rpc(State.ROUND_END)
	_broadcast_round_end.rpc(winning_team)
	await get_tree().create_timer(ROUND_END_DURATION).timeout
	_start_countdown()

@rpc("authority", "call_local", "reliable")
func _sync_state(new_state: int):
	state = new_state
	emit_signal("state_changed", new_state)

@rpc("authority", "call_local", "reliable")
func _sync_scores(new_scores: Dictionary):
	scores = new_scores
	for team in scores:
		emit_signal("score_updated", team, scores[team])

@rpc("authority", "call_local", "reliable")
func _broadcast_round_end(winning_team: int):
	emit_signal("round_ended", winning_team)
