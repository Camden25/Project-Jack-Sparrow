extends CharacterBody3D
class_name Player

var SPEED = 10.0
var JUMP_VELOCITY = 6.0
var SENSITIVITY = 0.003
var AIR_CONTROL = 0.3

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

func _enter_tree():
	var peer_id = int(name)
	set_multiplayer_authority(peer_id)
	
	var sync = get_node_or_null("MultiplayerSynchronizer")
	if sync:
		sync.set_multiplayer_authority(peer_id)

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
	if not is_multiplayer_authority():
		interpolation_controller.add_snapshot(net_position, net_rotation, net_head_rotation)
		interpolation_controller.interpolate(delta)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	if not spawn_confirmed:
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
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
	
	if multiplayer.is_server():
		lag_buffer.record()

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
