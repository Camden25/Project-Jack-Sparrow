extends Ability
class_name GrappleAbility

const MAX_DISTANCE := 30.0

const PULL_FORCE := 20.0
const AIR_ACCEL := 20.0
const REEL_SPEED := 35.0

const LAUNCH_IMPULSE := 6.0
const MIN_SWING_SPEED := 12.0

var grappling := false
var grapple_point := Vector3.ZERO
var rope_length := 0.0

var _rope_mesh_instance: MeshInstance3D
var _rope_mesh: CylinderMesh

@export var net_grapple_point: Vector3 = Vector3.ZERO
@export var net_is_grappling: bool = false

func try_activate():
	if not _can_activate():
		return
	_activate()

func _activate():
	var camera: Camera3D = owner_player.camera
	var from = camera.global_position
	var to = from + (-camera.global_basis.z * MAX_DISTANCE)
	var space = owner_player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [owner_player]
	var result = space.intersect_ray(query)
	if result.is_empty():
		return
	
	grapple_point = result.position
	rope_length = owner_player.global_position.distance_to(grapple_point)
	grappling = true
	net_is_grappling = true
	net_grapple_point = grapple_point
	
	# Launch impulse
	var launch_dir = (grapple_point - owner_player.global_position).normalized()
	owner_player.velocity += launch_dir * LAUNCH_IMPULSE

func physics_update(delta):
	if owner_player.is_multiplayer_authority():
		net_is_grappling = grappling
		net_grapple_point = grapple_point
	
	_update_rope_visual()
	
	if not grappling:
		return
	if not owner_player.is_multiplayer_authority():
		return
	
	var player_pos = owner_player.global_position
	var offset = player_pos - grapple_point
	var distance = offset.length()
	
	if distance < 0.2:
		grappling = false
		return
	
	var rope_dir = offset.normalized()
	
	# Rope constraint
	if distance > rope_length:
		var outward_speed = owner_player.velocity.dot(rope_dir)
		if outward_speed > 0.0:
			owner_player.velocity -= rope_dir * outward_speed
	
	# Pull
	var current_speed = owner_player.velocity.length()
	var pull_multiplier = clampf(1.0 - (current_speed / 20.0), 0.3, 2.0)
	owner_player.velocity += (-rope_dir * PULL_FORCE * pull_multiplier) * delta
	
	# Swing acceleration from input
	var move = dir_from_input()
	move -= rope_dir * move.dot(rope_dir)
	if move.length_squared() > 0:
		move = move.normalized()
		owner_player.velocity += move * AIR_ACCEL * delta
	
	var tangent_velocity = owner_player.velocity - rope_dir * owner_player.velocity.dot(rope_dir)
	if tangent_velocity.length() < MIN_SWING_SPEED and move.length_squared() > 0:
		var boost_dir = tangent_velocity.normalized() if tangent_velocity.length() > 0.01 else move
		owner_player.velocity += boost_dir * (MIN_SWING_SPEED - tangent_velocity.length()) * delta * 5.0
	
	# Reel in
	if Input.is_action_pressed("jump"):
		rope_length -= REEL_SPEED * delta
		rope_length = max(4.0, rope_length)
	
	# Release
	if not Input.is_action_pressed("secondary_fire"):
		grappling = false
		if data.cooldown > 0:
			_start_cooldown()

func _setup_rope() -> void:
	_rope_mesh = CylinderMesh.new()
	_rope_mesh_instance = MeshInstance3D.new()
	_rope_mesh_instance.mesh = _rope_mesh
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.526, 0.219, 0.59, 1.0)
	_rope_mesh_instance.material_override = mat
	owner_player.add_child(_rope_mesh_instance)
	_rope_mesh.top_radius = 0.04
	_rope_mesh.bottom_radius = _rope_mesh.top_radius
	_rope_mesh_instance.visible = false

func _update_rope_visual():
	if not _rope_mesh_instance:
		_setup_rope()
	if not grappling:
		_rope_mesh_instance.visible = false
		return
	
	var camera: Camera3D = owner_player.get_node("Head/Camera3D")
	var hand_pos: Vector3 = camera.global_position
	hand_pos += camera.global_basis.x * 0.25
	hand_pos += -camera.global_basis.y * 0.2
	
	_rope_mesh.height = hand_pos.distance_to(grapple_point)
	
	var dir = hand_pos.direction_to(grapple_point)
	
	_rope_mesh_instance.global_position = (hand_pos + grapple_point) * 0.5
	_rope_mesh_instance.look_at(grapple_point, Vector3.UP)
	_rope_mesh_instance.rotate_object_local(Vector3.RIGHT, PI / 2)
	
	_rope_mesh_instance.visible = true

func dir_from_input() -> Vector3:
	var camera = owner_player.camera
	
	var forward = -camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	
	var right = camera.global_basis.x
	right.y = 0
	right = right.normalized()
	
	var input = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	
	return (right * input.x + forward * input.y).normalized()
