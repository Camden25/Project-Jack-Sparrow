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
var _smoke_outline: MeshInstance3D
var _smoke_outline_canvas_layer: CanvasLayer
var _smoke_outline_viewport: SubViewport
var _smoke_outline_camera: Camera3D
var _team_outline: MeshInstance3D
var _team_outline_material: ShaderMaterial
var _is_active: bool = true

const SMOKE_OUTLINE_RENDER_LAYER := 19
const SMOKE_OUTLINE_RENDER_MASK := 1 << (SMOKE_OUTLINE_RENDER_LAYER - 1)
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
	PlayerManager.team_assigned.connect(_on_team_assigned)
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
	if peer_id == get_multiplayer_authority() or peer_id == multiplayer.get_unique_id():
		_update_team_outline()

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
	_team_outline.visible = _is_active

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

func set_smoke_outline_visible(is_visible: bool):
	if is_instance_valid(_smoke_outline):
		_smoke_outline.visible = is_visible

func _unhandled_input(event):
	if not is_multiplayer_authority():
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
	if is_multiplayer_authority():
		_sync_smoke_outline_camera()
	elif (
		is_instance_valid(interpolation_controller)
		and not interpolation_controller.is_queued_for_deletion()
	):
		interpolation_controller.add_snapshot(net_position, net_rotation, net_head_rotation)
		interpolation_controller.interpolate(delta)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	if not spawn_confirmed:
		return
	
	if not is_on_floor():
		velocity.y -= gravity * GRAVITY_MULTIPLIER * delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if not movement_override:
		var speed = SPEED
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
	$MeshInstance3D.visible = active
	_update_team_outline()
	if world_health_bar:
		world_health_bar.visible = active

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
