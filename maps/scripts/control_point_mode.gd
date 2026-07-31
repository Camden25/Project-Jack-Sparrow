extends GameMode
class_name ControlPointMode

@export var wins_needed: int = 1

var team_wins: Dictionary = { 0: 0, 1: 0 }

signal wins_updated(team_wins: Dictionary)

func start_round():
	var world = SceneManager.get_world()
	if not world:
		push_error("ControlPointMode: world not found")
		return
	
	var cp = world.get_node_or_null("ControlPoint")
	if not cp:
		push_error("ControlPointMode: ControlPoint not found in world")
		return
	
	cp.reset()
	
	if not cp.captured.is_connected(_on_point_captured):
		cp.captured.connect(_on_point_captured)
	if not cp.progress_changed.is_connected(_on_progress_changed):
		cp.progress_changed.connect(_on_progress_changed)
	
	_sync_round_started.rpc()
	emit_signal("round_started")

func _on_point_captured(team: int):
	if not multiplayer.is_server():
		return
	team_wins[team] += 1
	_sync_wins.rpc(team_wins)
	
	if team_wins[team] >= wins_needed:
		end_round(team)
	else:
		await get_tree().create_timer(3.0).timeout
		start_round()

func _on_progress_changed(new_progress: Dictionary):
	emit_signal("objective_progress_updated", new_progress)

func on_wins_changed(new_wins: Dictionary):
	emit_signal("wins_updated", new_wins)

@rpc("authority", "call_local", "reliable")
func _sync_wins(wins: Dictionary):
	team_wins = wins
	emit_signal("wins_updated", wins)
	GameModeEvents.emit_signal("wins_updated", wins)
