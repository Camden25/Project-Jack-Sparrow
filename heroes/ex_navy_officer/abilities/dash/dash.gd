extends Ability
class_name DashAbility

const DASH_SPEED: float = 40.0
const DASH_DURATION: float = 0.2

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO

func _activate():
	print("dash activated")
	
	var dir: Vector3 = dir_from_input()
	
	if dir.length_squared() > 0:
		dash_direction = dir
	else:
		var forward = -owner_player.get_node("Head/Camera3D").global_basis.z
		forward.y = 0
		forward = forward.normalized()
		dash_direction = forward
	
	is_dashing = true
	dash_timer = DASH_DURATION
	owner_player.movement_override = true

func _process(delta: float):
	super._process(delta)

func dir_from_input() -> Vector3:
	var camera: Camera3D = owner_player.get_node("Head/Camera3D")
	var basis := camera.global_basis
	
	var forward := -basis.z
	forward.y = 0
	forward = forward.normalized()
	
	var right := basis.x
	right.y = 0
	right = right.normalized()
	
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	).normalized()
	
	return (input.x * right + input.y * forward).normalized()

func physics_update(delta: float):
	if not is_dashing:
		return
	if not owner_player or not owner_player.is_multiplayer_authority():
		return
	
	dash_timer -= delta
	if dash_timer <= 0:
		is_dashing = false
		
		owner_player.velocity = owner_player.SPEED * dir_from_input()
		owner_player.movement_override = false
		
		return
	
	owner_player.velocity.x = dash_direction.x * DASH_SPEED
	owner_player.velocity.z = dash_direction.z * DASH_SPEED
	owner_player.velocity.y = 0
