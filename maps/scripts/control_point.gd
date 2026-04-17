extends Area3D

const CAPTURE_RATE: float = 0.01 # progress per second

var progress: Dictionary = { 0 : 0, 1 : 0 } # 0 = team A, 1 = team B
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
		else:
			team_b_count += 1
	
	if team_a_count > 0 and team_b_count > 0:
		return
	
	var old_progress = progress
	
	if team_a_count > 0 and controlling_team != PlayerManager.Team.TEAM_A:
		controlling_team = PlayerManager.Team.TEAM_A
		_sync_captured.rpc(PlayerManager.Team.TEAM_A)
	elif team_b_count > 0 and controlling_team != PlayerManager.Team.TEAM_B:
		controlling_team = PlayerManager.Team.TEAM_B
		_sync_captured.rpc(PlayerManager.Team.TEAM_B)
	
	if controlling_team == PlayerManager.Team.TEAM_A:
		progress[0] += CAPTURE_RATE * delta
	elif team_b_count > 0:
		progress[1] += CAPTURE_RATE * delta
	
	if old_progress != progress:
		_sync_progress.rpc(progress)
	
	if progress[0] >= 1:
		print("team a wins!")
	elif progress[1] >= 1:
		print("team b wins!")
	else:
		print("team a progress: ", float(int(1000*progress[0]))/10, "   team b progress: ", float(int(1000*progress[1]))/10)

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
