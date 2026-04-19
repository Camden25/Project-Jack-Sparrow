extends Area3D

const PROGRESS_RATE: float = 0.01 # progress per second
const CAPTURE_RATE: float = 0.2 # capture per second

var progress: Dictionary = { 0 : 0, 1 : 0 }
var capture_progress: float = 0.5 # 0 = team A, 1 = team B
var controlling_team: PlayerManager.Team = PlayerManager.Team.NONE
var players_in_zone: Array = []

signal captured(team: PlayerManager.Team)
signal progress_changed(new_progress: Dictionary)

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float):
	if not multiplayer.is_server():
		return
	
	var team_a_count = 0
	var team_b_count = 0
	
	for player in players_in_zone:
		if not is_instance_valid(player):
			continue
		var team = PlayerManager.get_team(player.get_multiplayer_authority())
		if team == PlayerManager.Team.TEAM_A:
			team_a_count += 1
		if team == PlayerManager.Team.TEAM_B:
			team_b_count += 1
	
	var old_progress = progress.duplicate()
	
	if controlling_team == PlayerManager.Team.TEAM_A:
		progress[0] += PROGRESS_RATE * delta
	if controlling_team == PlayerManager.Team.TEAM_B:
		progress[1] += PROGRESS_RATE * delta
	
	if old_progress != progress:
		_sync_progress.rpc(progress)
	
	if team_a_count > 0 and team_b_count > 0:
		return
	
	if team_a_count > 0 and controlling_team != PlayerManager.Team.TEAM_A:
		capture_progress -= CAPTURE_RATE * delta
	elif team_b_count > 0 and controlling_team != PlayerManager.Team.TEAM_B:
		capture_progress += CAPTURE_RATE * delta
	
	if capture_progress <= 0.0:
		controlling_team = PlayerManager.Team.TEAM_A
		_sync_captured.rpc(PlayerManager.Team.TEAM_A)
	if capture_progress >= 1.0:
		controlling_team = PlayerManager.Team.TEAM_B
		_sync_captured.rpc(PlayerManager.Team.TEAM_B)
	
	capture_progress = clamp(capture_progress, 0.0, 1.0)
	

@rpc("authority", "call_local", "unreliable")
func _sync_progress(new_progress: Dictionary):
	progress = new_progress
	emit_signal("progress_changed", new_progress)

@rpc("authority", "call_local", "reliable")
func _sync_captured(team: int):
	controlling_team = team as PlayerManager.Team
	emit_signal("captured", team)

func _on_body_entered(body: Node3D):
	if body is Player and not players_in_zone.has(body):
		players_in_zone.append(body)

func _on_body_exited(body: Node3D):
	players_in_zone.erase(body)
