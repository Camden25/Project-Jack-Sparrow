extends StaticBody3D
class_name TeamWall

const TEAM_A_GATE_LAYER: int = 3
const TEAM_B_GATE_LAYER: int = 4

@export_enum("Team A", "Team B") var pass_team: int = PlayerManager.Team.TEAM_A:
	set(value):
		pass_team = value
		_update_collision_layer()

func _ready() -> void:
	_update_collision_layer()

func _update_collision_layer() -> void:
	collision_layer = 0
	set_collision_layer_value(
		TEAM_A_GATE_LAYER,
		pass_team == PlayerManager.Team.TEAM_B
	)
	set_collision_layer_value(
		TEAM_B_GATE_LAYER,
		pass_team == PlayerManager.Team.TEAM_A
	)
	collision_mask = 0
