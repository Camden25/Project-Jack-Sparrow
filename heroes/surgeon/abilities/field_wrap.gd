extends SurgeonHealAbility
class_name FieldWrap

@export_range(1, 100, 1) var heal_amount: int = 45
@export_range(0.5, 5.0, 0.1) var treatment_range: float = 2.2
@export_range(0.1, 5.0, 0.1) var channel_duration: float = 1.25
@export_range(0.1, 0.9, 0.05) var movement_speed_multiplier: float = 0.5

var _is_applying: bool = false
var _server_active_treatment: bool = false
var _range_indicator: MeshInstance3D

var is_applying: bool:
	get:
		return _is_applying

func setup(player: HeroBase):
	super.setup(player)
	if not player.is_multiplayer_authority():
		return

	var ring := TorusMesh.new()
	ring.inner_radius = treatment_range - 0.04
	ring.outer_radius = treatment_range + 0.04
	ring.rings = 48
	ring.ring_segments = 8

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.35, 0.9, 0.55, 0.7)

	_range_indicator = MeshInstance3D.new()
	_range_indicator.name = "FieldWrapRangeIndicator"
	_range_indicator.mesh = ring
	_range_indicator.material_override = material
	_range_indicator.position.y = 0.04
	_range_indicator.visible = false
	player.add_child(_range_indicator)

func _can_activate() -> bool:
	return (
		super._can_activate()
		and not _is_applying
		#and not _get_allies_in_range(treatment_range).is_empty()
	)

func _activate():
	if not owner_player or not owner_player.is_multiplayer_authority():
		return
	
	_is_applying = true
	owner_player.movement_speed_multiplier = movement_speed_multiplier
	if is_instance_valid(_range_indicator):
		_range_indicator.visible = true
	if multiplayer.is_server():
		_server_begin_treatment(multiplayer.get_unique_id())
	else:
		_request_treatment_start.rpc_id(1)
	_finish_treatment()

func _finish_treatment() -> void:
	await get_tree().create_timer(channel_duration).timeout
	if not is_instance_valid(owner_player) or not _is_applying:
		return
	
	owner_player.movement_speed_multiplier = 1.0
	_is_applying = false
	if is_instance_valid(_range_indicator):
		_range_indicator.visible = false

func cancel():
	if _is_applying and is_instance_valid(owner_player):
		owner_player.movement_speed_multiplier = 1.0
	_is_applying = false
	_server_active_treatment = false
	if is_instance_valid(_range_indicator):
		_range_indicator.visible = false

@rpc("any_peer", "call_remote", "reliable")
func _request_treatment_start():
	if not multiplayer.is_server():
		return
	_server_begin_treatment(multiplayer.get_remote_sender_id())

func _server_begin_treatment(sender_id: int) -> void:
	if not is_instance_valid(owner_player) or _server_active_treatment:
		return
	if not _validate_server_use(sender_id):
		return
	
	_server_active_treatment = true
	_apply_treatment_over_time()

func _apply_treatment_over_time() -> void:
	var tick_count := maxi(ceili(channel_duration / 0.25), 1)
	var tick_duration := channel_duration / float(tick_count)
	
	for tick_index in range(tick_count):
		await get_tree().create_timer(tick_duration).timeout
		if not _server_active_treatment or not is_instance_valid(owner_player):
			break
		
		var previous_total := roundi(float(heal_amount) * tick_index / tick_count)
		var current_total := roundi(float(heal_amount) * (tick_index + 1) / tick_count)
		var tick_healing := current_total - previous_total
		var current_targets := _get_allies_in_range(treatment_range)
		for target in current_targets:
			if _has_clear_treatment_line(target):
				_apply_healing(target, tick_healing)
	
	_server_active_treatment = false

func _has_clear_treatment_line(target: Node3D) -> bool:
	var origin := owner_player.global_position + Vector3.UP
	var target_position := target.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(origin, target_position)
	query.exclude = [owner_player.get_rid()]
	var result := owner_player.get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty() or _find_player_root(result["collider"] as Node) == target

func _get_allies_in_range(max_distance: float) -> Array[Node3D]:
	var allies: Array[Node3D] = []
	var max_distance_squared := max_distance * max_distance
	for candidate in _get_players_and_dummies():
		if not candidate is Node3D or not _is_ally_target(candidate):
			continue
		var candidate_3d := candidate as Node3D
		if (
			owner_player.global_position.distance_squared_to(candidate_3d.global_position)
			<= max_distance_squared
		):
			allies.append(candidate_3d)
	return allies
