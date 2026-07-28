extends Node
class_name GameMode

signal round_started
signal round_ended(winning_team: int)
signal objective_progress_updated(data: Dictionary)
signal objective_state_changed(data: Dictionary)

# Override in subclasses
func start_round():
	pass

func end_round(winning_team: int):
	emit_signal("round_ended", winning_team)
	_sync_round_ended.rpc(winning_team)

func get_mode_name() -> String:
	return "Base"

@rpc("authority", "call_local", "reliable")
func _sync_round_ended(winning_team: int):
	emit_signal("round_ended", winning_team)

@rpc("authority", "call_local", "reliable")  
func _sync_round_started():
	emit_signal("round_started")
