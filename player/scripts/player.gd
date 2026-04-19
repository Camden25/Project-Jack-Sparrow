extends CharacterBody3D
class_name Player

const SPEED = 10.0
const JUMP_VELOCITY = 6.0
const SENSITIVITY = 0.003
const AIR_CONTROL = 0.3

#dash stuff
const DASH_SPEED: float = 30.0
const DASH_DURATION: float = 0.15
const DASH_COOLDOWN: float = 3.0

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO

signal dash_cooldown_changed(remaining: float, total: float)
#end dash stuff

var spawn_confirmed: bool = false

@export var net_position: Vector3
@export var net_rotation: Vector3  
@export var net_head_rotation: Vector3

@onready var interpolation_controller = $InterpolationController
@onready var health_component = $PlayerHealth
@onready var lag_buffer = $LagCompensationBuffer

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

@onready var weapon_holder = $Head/WeaponHolder
@onready var world_health_bar = $WorldHealthBar

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _enter_tree():
	var peer_id = int(name)
	set_multiplayer_authority(peer_id)

func _ready():
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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	interpolation_controller.queue_free()
	
	if multiplayer.is_server():
		health_component.player_died.connect(_on_player_died)

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SENSITIVITY)
		head.rotate_x(-event.relative.y * SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	
	if event.is_action_pressed("fire"):
		var weapon = weapon_holder.get_child(0) if weapon_holder.get_child_count() > 0 else null
		if weapon:
			var origin = $Head/Camera3D.global_position
			var direction = -$Head/Camera3D.global_basis.z
			weapon.try_fire(origin, direction)
	
	if event.is_action_pressed("reload"):
		var weapon = weapon_holder.get_child(0) if weapon_holder.get_child_count() > 0 else null
		if weapon:
			weapon.reload()
	
	if event.is_action_pressed("ability1"):
		_try_dash()

func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		interpolation_controller.add_snapshot(net_position, net_rotation, net_head_rotation)
		interpolation_controller.interpolate(delta)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	
	if not spawn_confirmed:
		print("spawn not confirmed for ", name)
		return
	
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	_tick_dash(delta)
	
	if is_dashing:
		velocity.x = dash_direction.x * DASH_SPEED
		velocity.z = dash_direction.z * DASH_SPEED
	else:
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
			# Air control
			velocity.x = lerp(velocity.x, direction.x * speed, AIR_CONTROL * delta * 10)
			velocity.z = lerp(velocity.z, direction.z * speed, AIR_CONTROL * delta * 10)
	
	move_and_slide()
	
	net_position = position
	net_rotation = rotation
	net_head_rotation = head.rotation
	
	if multiplayer.is_server():
		lag_buffer.record()

func _try_dash():
	if is_dashing or dash_cooldown_timer > 0:
		return
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Dash in input direction or forward if no input
	if input_dir != Vector2.ZERO:
		dash_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		dash_direction = -transform.basis.z
	
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	emit_signal("dash_cooldown_changed", dash_cooldown_timer, DASH_COOLDOWN)

func _tick_dash(delta: float):
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		dash_cooldown_timer = max(0.0, dash_cooldown_timer)
		emit_signal("dash_cooldown_changed", dash_cooldown_timer, DASH_COOLDOWN)

func _setup_health_bar(peer_id: int):
	print("_setup_health_bar called for ", peer_id, " on client ", multiplayer.get_unique_id())
	print("player registry: ", PlayerManager.player_registry)
	var player_name = PlayerManager.get_player_name(peer_id)
	var player_team = PlayerManager.get_team(peer_id)
	world_health_bar.setup(player_name, player_team)
	health_component.health_changed.connect(func(h): world_health_bar.update_health(h, health_component.MAX_HEALTH))
	world_health_bar.update_health(health_component.health, health_component.MAX_HEALTH)

func set_active(active: bool):
	set_physics_process(active and is_multiplayer_authority())
	set_process_unhandled_input(active and is_multiplayer_authority())
	$CollisionShape3D.disabled = not active
	$MeshInstance3D.visible = active
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
