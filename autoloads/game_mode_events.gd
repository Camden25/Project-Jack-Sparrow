extends Node

signal objective_progress_updated(data: Dictionary)
signal objective_state_changed(data: Dictionary)
signal round_started
signal round_ended(winning_team: int)
signal wins_updated(team_wins: Dictionary)

func connect_to_mode(mode: GameMode):
	# Clear previous connections
	if mode.round_started.is_connected(_on_round_started):
		mode.round_started.disconnect(_on_round_started)
	
	mode.round_started.connect(_on_round_started)
	mode.round_ended.connect(_on_round_ended)
	mode.objective_progress_updated.connect(_on_objective_progress_updated)
	
	if mode is ControlPointMode:
		mode.wins_updated.connect(_on_wins_updated)

func _on_round_started():
	emit_signal("round_started")

func _on_round_ended(winning_team: int):
	emit_signal("round_ended", winning_team)

func _on_objective_progress_updated(data: Dictionary):
	emit_signal("objective_progress_updated", data)

func _on_wins_updated(team_wins: Dictionary):
	emit_signal("wins_updated", team_wins)
