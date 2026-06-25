extends HitscanWeaponBase
class_name Musket

# Musket specific stats — these override whatever is in WeaponData
# for things that need code-level control

var is_aiming: bool = false
var aim_fov: float = 40.0
var default_fov: float = 75.0
var fov_lerp_speed: float = 10.0

signal aim_changed(aiming: bool)

func _ready():
	# Listen for aim input — handled here not in HeroBase
	# since aiming is weapon-specific
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
