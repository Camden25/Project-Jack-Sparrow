extends Ability
class_name RetreatAbility

const DASH_SPEED: float = 30.0
const DASH_DURATION: float = 0.15

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO

func _activate():
	print("retreat activated")
	dash_direction = owner_player.get_node("Head/Camera3D").global_basis.z.normalized()
	dash_direction.y = 0.0
	if dash_direction == Vector3.ZERO:
		dash_direction = owner_player.transform.basis.z
	is_dashing = true
	dash_timer = DASH_DURATION

func _process(delta: float):
	super._process(delta)
	
	if not is_dashing:
		return
	if not owner_player or not owner_player.is_multiplayer_authority():
		return
	
	dash_timer -= delta
	if dash_timer <= 0:
		is_dashing = false
		return
	
	owner_player.velocity.x = dash_direction.x * DASH_SPEED
	owner_player.velocity.z = dash_direction.z * DASH_SPEED
