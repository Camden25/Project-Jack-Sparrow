extends HitscanWeaponBase
class_name BurstRifle

@export_range(2, 5, 1) var burst_size: int = 3
@export_range(0.0, 0.25, 0.01) var burst_interval: float = 0.08
@export_range(0.0, 0.15, 0.005) var spread: float = 0.02

var is_bursting: bool = false

func try_fire():
	if is_bursting or not data or not _can_fire or is_reloading or current_ammo <= 0:
		return

	_can_fire = false
	_fire_timer = 0.0
	var shots_to_fire := mini(burst_size, current_ammo)
	current_ammo -= shots_to_fire
	ammo_changed.emit(current_ammo, data.max_ammo)
	is_bursting = true
	_fire_burst(shots_to_fire)

func reload():
	if is_bursting:
		return
	super.reload()

func _fire_burst(shots_to_fire: int) -> void:
	for shot_index in range(shots_to_fire):
		if not is_instance_valid(owner_player):
			is_bursting = false
			return
		_fire_single_shot()
		if shot_index < shots_to_fire - 1:
			await get_tree().create_timer(burst_interval).timeout

	is_bursting = false
	if current_ammo == 0:
		reload()

func _fire_single_shot() -> void:
	var camera := owner_player.get_node_or_null("Head/Camera3D") as Camera3D
	if not camera:
		push_error("BurstRifle could not find the owner's camera")
		return

	var direction := _get_fire_direction()
	var tracer_origin := camera.global_position
	if muzzle:
		tracer_origin = muzzle.global_position
	_spawn_tracer(tracer_origin, direction)

	var shooter_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		_run_validation(camera.global_position, direction, shooter_id)
	else:
		_server_validate_shot.rpc_id(1, camera.global_position, direction, shooter_id)

func _get_fire_direction() -> Vector3:
	var camera := owner_player.get_node_or_null("Head/Camera3D") as Camera3D
	if not camera:
		return Vector3.ZERO

	var forward := -camera.global_basis.z
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	return (
		forward
		+ right * randf_range(-spread, spread)
		+ up * randf_range(-spread, spread)
	).normalized()
