extends HitscanWeaponBase
class_name Musket
	
var is_aiming: bool = false
var aim_fov: float = 40.0
var default_fov: float = 75.0
var fov_lerp_speed: float = 10.0

signal aim_changed(aiming: bool)

func _ready():
	pass

func setup(player: HeroBase):
	super.setup(player)

func try_fire():
	if not is_aiming:
		return
	super.try_fire()

func _get_fire_direction() -> Vector3:
	var camera = owner_player.get_node("Head/Camera3D")
	var base_direction = -camera.global_basis.z
	
	return base_direction

func start_aim():
	if not owner_player.is_multiplayer_authority():
		return
	is_aiming = true
	emit_signal("aim_changed", true)

func stop_aim():
	if not owner_player.is_multiplayer_authority():
		return
	is_aiming = false
	emit_signal("aim_changed", false)

func _process(delta: float):
	super._process(delta)
	
	if not owner_player or not owner_player.is_multiplayer_authority():
		return
	
	# Smooth FOV transition for aim down sights
	var camera = owner_player.get_node_or_null("Head/Camera3D")
	if camera:
		var target_fov = aim_fov if is_aiming else default_fov
		camera.fov = lerp(camera.fov, target_fov, fov_lerp_speed * delta)
	
	# Handle aim input here since it's weapon-specific
	if Input.is_action_pressed("secondary_fire") != is_aiming:
		if Input.is_action_pressed("secondary_fire"):
			start_aim()
		else:
			stop_aim()

	_update_smoke_outlines()

func _update_smoke_outlines():
	var owner_team := PlayerManager.get_team(owner_player.get_multiplayer_authority())
	for player_node in get_tree().get_nodes_in_group("players"):
		var candidate := player_node as Player
		if not candidate or candidate == owner_player:
			continue
		
		var should_reveal := false
		var candidate_team := PlayerManager.get_team(candidate.get_multiplayer_authority())
		if (
			is_aiming
			and owner_team != PlayerManager.Team.NONE
			and candidate_team != PlayerManager.Team.NONE
			and candidate_team != owner_team
		):
			for smoke_node in get_tree().get_nodes_in_group("smoke_effects"):
				var smoke: SmokeEffect = smoke_node as SmokeEffect
				if smoke and smoke.contains_position(candidate.global_position):
					should_reveal = true
					break
		
		candidate.set_smoke_outline_visible(should_reveal)
