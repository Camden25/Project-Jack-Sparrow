extends Area3D

const PROGRESS_RATE: float = 0.01
const CAPTURE_RATE: float = 0.2
const OVERTIME_THRESHOLD: float = 0.99

var progress: Dictionary = { 0: 0.0, 1: 0.0 }
var capture_progress: float = 0.5
var controlling_team: PlayerManager.Team = PlayerManager.Team.NONE
var players_in_zone: Array = []
var _win_fired: bool = false

signal captured(team: PlayerManager.Team)
signal control_changed(team: PlayerManager.Team)
signal progress_changed(new_progress: Dictionary)

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func reset():
	progress = { 0: 0.0, 1: 0.0 }
	capture_progress = 0.5
	controlling_team = PlayerManager.Team.NONE
	_win_fired = false
	_sync_reset.rpc()

func _physics_process(delta: float):
	if not multiplayer.is_server():
		return
	if _win_fired:
		return

	var team_a_count = 0
	var team_b_count = 0

	for player in players_in_zone:
		if not is_instance_valid(player):
			continue
		var team = PlayerManager.get_team(player.get_multiplayer_authority())
		if team == PlayerManager.Team.TEAM_A:
			team_a_count += 1
		elif team == PlayerManager.Team.TEAM_B:
			team_b_count += 1
	
	var contested = team_a_count > 0 and team_b_count > 0
	
	var old_progress = progress.duplicate()
	
	if controlling_team == PlayerManager.Team.TEAM_A:
		var cap = OVERTIME_THRESHOLD if contested else 1.0
		progress[0] = minf(progress[0] + PROGRESS_RATE * delta, cap)
	elif controlling_team == PlayerManager.Team.TEAM_B:
		var cap = OVERTIME_THRESHOLD if contested else 1.0
		progress[1] = minf(progress[1] + PROGRESS_RATE * delta, cap)
	
	if old_progress != progress:
		_sync_progress.rpc(progress)
	
	if not contested and not _win_fired:
		if progress[0] >= 1.0:
			_win_fired = true
			_sync_captured.rpc(PlayerManager.Team.TEAM_A)
			return
		elif progress[1] >= 1.0:
			_win_fired = true
			_sync_captured.rpc(PlayerManager.Team.TEAM_B)
			return
	
	# Handle recapture
	if contested:
		return
	
	var old_capture = capture_progress
	if team_a_count > 0 and controlling_team != PlayerManager.Team.TEAM_A:
		capture_progress -= CAPTURE_RATE * delta
	elif team_b_count > 0 and controlling_team != PlayerManager.Team.TEAM_B:
		capture_progress += CAPTURE_RATE * delta
	
	capture_progress = clampf(capture_progress, 0.0, 1.0)
	
	if old_capture != capture_progress:
		_sync_capture_progress.rpc(capture_progress)
	
	# Control change
	if capture_progress <= 0.0 and controlling_team != PlayerManager.Team.TEAM_A:
		controlling_team = PlayerManager.Team.TEAM_A
		_sync_control_changed.rpc(PlayerManager.Team.TEAM_A)
	elif capture_progress >= 1.0 and controlling_team != PlayerManager.Team.TEAM_B:
		controlling_team = PlayerManager.Team.TEAM_B
		_sync_control_changed.rpc(PlayerManager.Team.TEAM_B)

@rpc("authority", "call_local", "unreliable")
func _sync_progress(new_progress: Dictionary):
	progress = new_progress
	emit_signal("progress_changed", new_progress)
	GameModeEvents.emit_signal("objective_progress_updated", new_progress)

@rpc("authority", "call_local", "unreliable")
func _sync_capture_progress(new_capture: float):
	capture_progress = new_capture

@rpc("authority", "call_local", "reliable")
func _sync_control_changed(team: int):
	controlling_team = team as PlayerManager.Team
	emit_signal("control_changed", controlling_team)

@rpc("authority", "call_local", "reliable")
func _sync_captured(team: int):
	controlling_team = team as PlayerManager.Team
	emit_signal("captured", team as PlayerManager.Team)

@rpc("authority", "call_local", "reliable")
func _sync_reset():
	progress = { 0: 0.0, 1: 0.0 }
	capture_progress = 0.5
	controlling_team = PlayerManager.Team.NONE
	_win_fired = false

func _on_body_entered(body: Node3D):
	if body is Player and not players_in_zone.has(body):
		players_in_zone.append(body)

func _on_body_exited(body: Node3D):
	players_in_zone.erase(body)
