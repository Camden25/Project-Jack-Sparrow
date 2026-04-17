extends Node3D

@onready var health_fill: MeshInstance3D = $BillboardContainer/HealthBarFill
@onready var health_bg: MeshInstance3D = $BillboardContainer/HealthBarBG
@onready var name_label: Label3D = $BillboardContainer/NameLabel

const MAX_WIDTH: float = 1.0
const BAR_HEIGHT: float = 0.1
const OFFSET: Vector3 = Vector3(0, 2.2, 0)

var team: PlayerManager.Team = PlayerManager.Team.NONE

func setup(player_name: String, player_team: PlayerManager.Team):
	print("setting up health bar for ", player_name, " on team ", player_team)
	team = player_team
	name_label.text = player_name
	_update_color()

func update_health(current: int, maximum: int):
	print("updating health for ", name_label.text, " on team ", team)
	var ratio = float(current) / float(maximum)
	health_fill.scale.x = ratio
	health_fill.position.x = (ratio - 1.0) * MAX_WIDTH * 0.5

func _update_color():
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.RED if team == PlayerManager.Team.TEAM_B else Color.CYAN
	health_fill.set_surface_override_material(0, mat)

func _process(_delta: float):
	var camera = get_viewport().get_camera_3d()
	if camera:
		var dir = camera.global_position - global_position
		dir.y = 0
		if dir != Vector3.ZERO:
			look_at(global_position - dir)
	
	global_position = get_parent().global_position + OFFSET
