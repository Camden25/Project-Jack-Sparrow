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

@export var net_position: Vector3
@export var net_rotation: Vector3  
@export var net_head_rotation: Vector3

@onready var interpolation_controller = $InterpolationController
@onready var health_component = $PlayerHealth
@onready var lag_buffer = $LagCompensationBuffer

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

@onready var weapon_holder = $Head/WeaponHolder

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _enter_tree():
	var peer_id = int(name)
	set_multiplayer_authority(peer_id)

func _ready():
	# Only the owner gets camera and input
	print("name: ", name, "\t\tmultiplayer authority: ", is_multiplayer_authority())
	
	lag_buffer.setup(self)
	interpolation_controller.setup(self, head)
	
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

func _on_player_died(peer_id: int):
	print("Player died: " + str(peer_id))
