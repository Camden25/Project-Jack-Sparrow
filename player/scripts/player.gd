extends CharacterBody3D
class_name Player

var SPEED = 10.0
var JUMP_VELOCITY = 8.0
var SENSITIVITY = 0.003
var AIR_CONTROL = 0.3
var GRAVITY_MULTIPLIER = 1.35

var spawn_confirmed: bool = false

@export var net_position: Vector3
@export var net_rotation: Vector3  
@export var net_head_rotation: Vector3

@onready var interpolation_controller = $InterpolationController
@onready var health_component = $PlayerHealth
@onready var lag_buffer = $LagCompensationBuffer

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

@onready var weapon_holder = $Head/ViewmodelRoot
@onready var world_health_bar = $WorldHealthBar

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var movement_override: bool = false
var movement_speed_multiplier: float = 1.0
var crew_shot_speed_multiplier: float = 1.0
var _smoke_outline: MeshInstance3D
var _smoke_outline_canvas_layer: CanvasLayer
var _smoke_outline_viewport: SubViewport
var _smoke_outline_camera: Camera3D
var _team_outline: MeshInstance3D
var _team_outline_material: ShaderMaterial
var _crew_shot_ghost: MeshInstance3D
var _is_active: bool = true
var _crew_shot_invitation_cannoneer_id: int = -1
var _crew_shot_invitation_id: int = -1
var _crew_shot_carrier_id: int = -1
var _crew_shot_is_held: bool = false
var _crew_shot_carrier_missing_time: float = 0.0
var _smoke_outline_is_visible: bool = false

const SMOKE_OUTLINE_RENDER_LAYER := 19
const SMOKE_OUTLINE_RENDER_MASK := 1 << (SMOKE_OUTLINE_RENDER_LAYER - 1)
const TEAM_A_GATE_LAYER := 3
const TEAM_B_GATE_LAYER := 4
const VISIBLE_OUTLINE_SHADER = preload("res://player/shaders/visible_outline.gdshader")
const XRAY_OUTLINE_SHADER = preload("res://player/shaders/xray_outline.gdshader")
const ENEMY_OUTLINE_COLOR := Color(1.0, 0.08, 0.08)
const TEAMMATE_OUTLINE_COLOR := Color(0.08, 0.35, 1.0)

func _enter_tree():
	var peer_id = int(name)
	set_multiplayer_authority(peer_id)
	add_to_group("players")

	var sync = get_node_or_null("MultiplayerSynchronizer")
	if sync:
		sync.set_multiplayer_authority(peer_id)

func _ready():
	_setup_smoke_outline_viewport()
	_setup_smoke_outline()
	_setup_team_outline()
	_setup_crew_shot_ghost()
	PlayerManager.team_assigned.connect(_on_team_assigned)
	_update_gate_collision_mask()
	_update_team_outline()

	# Only the owner gets camera and input
	print("name: ", name, "\t\tmultiplayer authority: ", is_multiplayer_authority())
	
	lag_buffer.setup(self)
	interpolation_controller.setup(self, head)
	
	print("player position of ", name, " is ", global_position)
	
	var my_id = multiplayer.get_unique_id()
	var peer_id = get_multiplayer_authority()
	
	print("player ready — name: ", name, " peer_id: ", peer_id, " my_id: ", my_id, " is_authority: ", is_multiplayer_authority())
	print("world_health_bar is null: ", world_health_bar == null)
	
	if peer_id == my_id:
		print("queueing free health bar for local player")
		world_health_bar.queue_free()
	else:
		print("setting up health bar for remote player ", peer_id)
		print("registry has peer: ", PlayerManager.player_registry.has(peer_id))
		print("full registry: ", PlayerManager.player_registry)
		if PlayerManager.player_registry.has(peer_id):
			_setup_health_bar(peer_id)
		else:
			print("connecting to player_registered signal")
			PlayerManager.player_registered.connect(
				func(registered_id):
					print("player_registered fired for ", registered_id, " waiting for ", peer_id)
					if registered_id == peer_id:
						_setup_health_bar(peer_id)
			)
	
	if not is_multiplayer_authority():
		$Head/Camera3D.current = false
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	
	# Local player setup
	$Head/Camera3D.current = true
	_enable_smoke_outline_viewport()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	interpolation_controller.queue_free()
	
	if multiplayer.is_server():
		health_component.player_died.connect(_on_player_died)

func _setup_smoke_outline():
	var body_mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not body_mesh or not body_mesh.mesh:
		return

	_smoke_outline = body_mesh.duplicate() as MeshInstance3D
	_smoke_outline.name = "SmokeOutline"
	var outline_material := ShaderMaterial.new()
	outline_material.shader = preload("res://heroes/ex_navy_officer/abilities/smoke_canister/smoke_outline_mask.gdshader")
	_smoke_outline.material_override = outline_material
	_smoke_outline.layers = SMOKE_OUTLINE_RENDER_MASK
	_smoke_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_smoke_outline.visible = false
	body_mesh.add_sibling(_smoke_outline)

func _setup_team_outline():
	var body_mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not body_mesh or not body_mesh.mesh:
		return

	_team_outline = body_mesh.duplicate() as MeshInstance3D
	_team_outline.name = "TeamOutline"
	_team_outline_material = ShaderMaterial.new()
	_team_outline_material.shader = VISIBLE_OUTLINE_SHADER
	_team_outline_material.set_shader_parameter("outline_width", 0.045)
	_team_outline.material_override = _team_outline_material
	_team_outline.layers = body_mesh.layers
	_team_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_team_outline.visible = false
	body_mesh.add_sibling(_team_outline)

func _on_team_assigned(peer_id: int, _team: int):
	if peer_id == get_multiplayer_authority():
		_update_gate_collision_mask()
	if peer_id == get_multiplayer_authority() or peer_id == multiplayer.get_unique_id():
		_update_team_outline()

func _update_gate_collision_mask() -> void:
	var team := PlayerManager.get_team(get_multiplayer_authority())
	set_collision_mask_value(
		TEAM_A_GATE_LAYER,
		team == PlayerManager.Team.TEAM_A or team == PlayerManager.Team.NONE
	)
	set_collision_mask_value(
		TEAM_B_GATE_LAYER,
		team == PlayerManager.Team.TEAM_B or team == PlayerManager.Team.NONE
	)

func _update_team_outline():
	if not is_instance_valid(_team_outline) or not is_instance_valid(_team_outline_material):
		return

	var player_id := get_multiplayer_authority()
	var local_player_id := multiplayer.get_unique_id()
	var player_team := PlayerManager.get_team(player_id)
	var local_team := PlayerManager.get_team(local_player_id)

	if player_id == local_player_id or player_team < 0 or local_team < 0:
		_team_outline.visible = false
		return

	var is_teammate := player_team == local_team
	_team_outline_material.shader = XRAY_OUTLINE_SHADER if is_teammate else VISIBLE_OUTLINE_SHADER
	_team_outline_material.set_shader_parameter(
		"outline_color",
		TEAMMATE_OUTLINE_COLOR if is_teammate else ENEMY_OUTLINE_COLOR
	)
	var hidden_from_carrier := (
		_crew_shot_is_held
		and local_player_id == _crew_shot_carrier_id
	)
	_team_outline.visible = _is_active and not hidden_from_carrier

func _setup_smoke_outline_viewport():
	_smoke_outline_canvas_layer = get_node_or_null("SmokeOutlineLayer") as CanvasLayer
	_smoke_outline_viewport = get_node_or_null("SmokeOutlineLayer/ViewportContainer/OutlineViewport") as SubViewport
	_smoke_outline_camera = get_node_or_null("SmokeOutlineLayer/ViewportContainer/OutlineViewport/OutlineCamera3D") as Camera3D
	if not _smoke_outline_canvas_layer or not _smoke_outline_viewport or not _smoke_outline_camera:
		return

	_smoke_outline_canvas_layer.visible = false
	_smoke_outline_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_smoke_outline_viewport.world_3d = get_viewport().world_3d

func _enable_smoke_outline_viewport():
	if not _smoke_outline_canvas_layer or not _smoke_outline_viewport:
		return

	_smoke_outline_canvas_layer.visible = true
	_smoke_outline_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sync_smoke_outline_camera()

func _sync_smoke_outline_camera():
	if not _smoke_outline_camera:
		return

	_smoke_outline_camera.global_transform = camera.global_transform
	_smoke_outline_camera.fov = camera.fov
	_smoke_outline_camera.near = camera.near
	_smoke_outline_camera.far = camera.far
	_smoke_outline_camera.projection = camera.projection
	_smoke_outline_camera.keep_aspect = camera.keep_aspect
	_smoke_outline_camera.size = camera.size
	_smoke_outline_camera.h_offset = camera.h_offset
	_smoke_outline_camera.v_offset = camera.v_offset
	_smoke_outline_camera.frustum_offset = camera.frustum_offset

func set_smoke_outline_visible(smoke_visible: bool):
	_smoke_outline_is_visible = smoke_visible
	_update_crew_shot_visibility()

func handle_crew_shot_input(event: InputEvent) -> bool:
	if not is_multiplayer_authority():
		return false

	if _crew_shot_invitation_id >= 0:
		if event.is_action_pressed("crew_shot_interact"):
			_request_crew_shot_invitation(true)
			return true
		if event.is_action_pressed("crew_shot_decline"):
			_request_crew_shot_invitation(false)
			return true

	if _crew_shot_is_held:
		if event.is_action_pressed("crew_shot_interact"):
			_request_crew_shot_cancel()
			return true
		return not event is InputEventMouseMotion
	return false

func _request_crew_shot_invitation(accept: bool):
	var cannoneer := _get_crew_shot_cannoneer()
	var crew_shot = cannoneer.get_node_or_null("Abilities/CrewShot") if cannoneer else null
	if not crew_shot:
		_clear_crew_shot_invitation()
		return

	if accept:
		crew_shot.call("request_accept_from_client", _crew_shot_invitation_id)
	else:
		crew_shot.call("request_decline_from_client", _crew_shot_invitation_id)

func _request_crew_shot_cancel():
	var cannoneer := _get_crew_shot_cannoneer()
	var crew_shot = cannoneer.get_node_or_null("Abilities/CrewShot") if cannoneer else null
	if crew_shot:
		crew_shot.call("request_cancel_from_client")
	else:
		_set_crew_shot_held(-1, false, Vector3.ZERO)

func _get_crew_shot_cannoneer() -> Node:
	var players_node := SceneManager.get_players_node()
	if players_node and _crew_shot_invitation_cannoneer_id >= 0:
		return players_node.get_node_or_null(str(_crew_shot_invitation_cannoneer_id))
	if players_node and _crew_shot_carrier_id >= 0:
		return players_node.get_node_or_null(str(_crew_shot_carrier_id))
	return null

func _clear_crew_shot_invitation():
	_crew_shot_invitation_cannoneer_id = -1
	_crew_shot_invitation_id = -1
	if not is_multiplayer_authority():
		return
	var hud := get_tree().get_first_node_in_group("UI")
	if hud:
		hud.call("hide_crew_shot_prompt")

func set_crew_shot_invite_from_server(cannoneer_id: int, invitation_id: int, show_invite: bool):
	_set_crew_shot_invite(cannoneer_id, invitation_id, show_invite)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_crew_shot_invite(cannoneer_id: int, invitation_id: int, show_invite: bool):
	if multiplayer.get_remote_sender_id() != 1:
		return
	_set_crew_shot_invite(cannoneer_id, invitation_id, show_invite)

func _set_crew_shot_invite(cannoneer_id: int, invitation_id: int, show_invite: bool):
	if not is_multiplayer_authority():
		return
	if show_invite:
		_crew_shot_invitation_cannoneer_id = cannoneer_id
		_crew_shot_invitation_id = invitation_id
		var cannoneer_name := PlayerManager.get_player_name(cannoneer_id)
		var hud := get_tree().get_first_node_in_group("UI")
		if hud:
			hud.call(
				"show_crew_shot_prompt",
				cannoneer_name + " offers a cannon launch  |  G: accept  |  H: decline"
			)
	elif (
		_crew_shot_invitation_cannoneer_id == cannoneer_id
		and _crew_shot_invitation_id == invitation_id
	):
		_clear_crew_shot_invitation()

func set_crew_shot_held_from_server(cannoneer_id: int, is_held: bool, launch_velocity: Vector3):
	_set_crew_shot_held(cannoneer_id, is_held, launch_velocity)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_crew_shot_held(cannoneer_id: int, is_held: bool, launch_velocity: Vector3):
	if multiplayer.get_remote_sender_id() != 1:
		return
	_set_crew_shot_held(cannoneer_id, is_held, launch_velocity)

func _set_crew_shot_held(cannoneer_id: int, is_held: bool, launch_velocity: Vector3):
	if is_held:
		if _crew_shot_is_held and _crew_shot_carrier_id != cannoneer_id:
			return
		_clear_crew_shot_invitation()
		_crew_shot_carrier_id = cannoneer_id
		_crew_shot_is_held = true
		_crew_shot_carrier_missing_time = 0.0
		movement_override = true
		velocity = Vector3.ZERO
		$CollisionShape3D.set_deferred("disabled", true)
		_follow_crew_shot_carrier()
		_update_crew_shot_visibility()
		if is_multiplayer_authority():
			var hud := get_tree().get_first_node_in_group("UI")
			if hud:
				hud.call("show_crew_shot_prompt", "LOADED IN CANNON  |  G: cancel")
		return

	if not _crew_shot_is_held or _crew_shot_carrier_id != cannoneer_id:
		return
	_follow_crew_shot_carrier()
	_crew_shot_is_held = false
	_crew_shot_carrier_id = -1
	_crew_shot_carrier_missing_time = 0.0
	movement_override = false
	$CollisionShape3D.set_deferred("disabled", not _is_active)
	velocity = launch_velocity if health_component.health > 0 else Vector3.ZERO
	_update_crew_shot_visibility()
	if is_multiplayer_authority():
		var hud := get_tree().get_first_node_in_group("UI")
		if hud:
			hud.call("hide_crew_shot_prompt")

func _update_crew_shot_visibility():
	var hidden_from_carrier := (
		_crew_shot_is_held
		and multiplayer.get_unique_id() == _crew_shot_carrier_id
	)
	var body_mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if body_mesh:
		body_mesh.visible = _is_active and not hidden_from_carrier
	if is_instance_valid(_team_outline):
		_update_team_outline()
	if is_instance_valid(_smoke_outline):
		_smoke_outline.visible = _smoke_outline_is_visible and not hidden_from_carrier
	if is_instance_valid(_crew_shot_ghost):
		_crew_shot_ghost.visible = _is_active and hidden_from_carrier
	if is_instance_valid(world_health_bar):
		world_health_bar.visible = _is_active and not hidden_from_carrier

func _setup_crew_shot_ghost():
	var body_mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not body_mesh or not body_mesh.mesh:
		return

	_crew_shot_ghost = body_mesh.duplicate() as MeshInstance3D
	_crew_shot_ghost.name = "CrewShotGhost"
	var ghost_material := StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = Color(0.35, 0.8, 1.0, 0.35)
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_crew_shot_ghost.material_override = ghost_material
	_crew_shot_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crew_shot_ghost.visible = false
	body_mesh.add_sibling(_crew_shot_ghost)

func _follow_crew_shot_carrier():
	var carrier := _get_crew_shot_cannoneer() as Node3D
	if not carrier:
		return false
	var seat := carrier.get_node_or_null("CrewShotSeat") as Marker3D
	if seat:
		global_position = seat.global_position
	else:
		global_position = carrier.global_position + carrier.global_basis * Vector3(0.0, 0.9, -1.0)
	return true

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return

	if handle_crew_shot_input(event):
		return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SENSITIVITY)
		head.rotate_x(-event.relative.y * SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	
	if event.is_action_pressed("primary_fire"):
		var weapon = weapon_holder.get_child(0) if weapon_holder.get_child_count() > 0 else null
		if weapon:
			var origin = $Head/Camera3D.global_position
			var direction = -$Head/Camera3D.global_basis.z
			weapon.try_fire(origin, direction)
	
	if event.is_action_pressed("reload"):
		var weapon = weapon_holder.get_child(0) if weapon_holder.get_child_count() > 0 else null
		if weapon:
			weapon.reload()

func _process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() == false:
		return
	if is_multiplayer_authority():
		_sync_smoke_outline_camera()
	elif (
		is_instance_valid(interpolation_controller)
		and not interpolation_controller.is_queued_for_deletion()
	):
		interpolation_controller.add_snapshot(net_position, net_rotation, net_head_rotation)
		interpolation_controller.interpolate(delta)

func _physics_process(delta):
	if multiplayer.has_multiplayer_peer() == false:
		return
	if not is_multiplayer_authority():
		return
	if not spawn_confirmed:
		return
	if _crew_shot_is_held:
		if _follow_crew_shot_carrier():
			_crew_shot_carrier_missing_time = 0.0
		else:
			_crew_shot_carrier_missing_time += delta
			if _crew_shot_carrier_missing_time >= 1.0:
				_set_crew_shot_held(_crew_shot_carrier_id, false, Vector3.ZERO)
		if _crew_shot_is_held:
			velocity = Vector3.ZERO
			net_position = position
			net_rotation = rotation
			net_head_rotation = head.rotation
			return
	
	if not is_on_floor():
		velocity.y -= gravity * GRAVITY_MULTIPLIER * delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if not movement_override:
		var speed = SPEED * movement_speed_multiplier * crew_shot_speed_multiplier
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if is_on_floor():
			if direction:
				velocity.x = direction.x * speed
				velocity.z = direction.z * speed
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
				velocity.z = move_toward(velocity.z, 0, speed)
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, AIR_CONTROL * delta * 10)
			velocity.z = lerp(velocity.z, direction.z * speed, AIR_CONTROL * delta * 10)
	
	# HeroBase will call move_and_slide()
	
	net_position = position
	net_rotation = rotation
	net_head_rotation = head.rotation

func _setup_health_bar(peer_id: int):
	print("_setup_health_bar called for ", peer_id, " on client ", multiplayer.get_unique_id())
	print("player registry: ", PlayerManager.player_registry)
	var player_name = PlayerManager.get_player_name(peer_id)
	var player_team = PlayerManager.get_team(peer_id)
	world_health_bar.setup(player_name, player_team)
	health_component.health_changed.connect(func(h): world_health_bar.update_health(h, health_component.MAX_HEALTH))
	world_health_bar.update_health(health_component.health, health_component.MAX_HEALTH)

func set_active(active: bool):
	_is_active = active
	if not active:
		_clear_crew_shot_invitation()
		if _crew_shot_is_held:
			if multiplayer.is_server():
				var cannoneer := _get_crew_shot_cannoneer()
				var crew_shot = cannoneer.get_node_or_null("Abilities/CrewShot") if cannoneer else null
				if crew_shot:
					crew_shot.call(
						"cancel_passenger_from_server",
						get_multiplayer_authority()
					)
			_set_crew_shot_held(_crew_shot_carrier_id, false, Vector3.ZERO)
		movement_override = false
		velocity = Vector3.ZERO
		var abilities_node = get_node_or_null("Abilities")
		if abilities_node:
			for ability in abilities_node.get_children():
				if ability is Ability:
					ability.cancel()

	set_physics_process(active and is_multiplayer_authority())
	set_process_unhandled_input(active and is_multiplayer_authority())
	$CollisionShape3D.disabled = not active
	_update_crew_shot_visibility()
	_update_team_outline()

func confirm_spawn(spawn_pos: Vector3):
	print("confirm_spawn called on ", multiplayer.get_unique_id(), " pos: ", spawn_pos)
	global_position = spawn_pos
	spawn_confirmed = true

func confirm_respawn(spawn_pos: Vector3):
	spawn_confirmed = false
	global_position = spawn_pos
	await get_tree().process_frame
	spawn_confirmed = true

func _on_player_died(peer_id: int):
	print("Player died: " + str(peer_id))
