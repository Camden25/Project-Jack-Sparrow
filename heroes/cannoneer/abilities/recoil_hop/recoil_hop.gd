extends Ability
class_name RecoilHopAbility

@export_range(0.0, 30.0, 0.5) var horizontal_impulse: float = 9.0
@export_range(0.0, 20.0, 0.5) var upward_impulse: float = 6.0
@export_range(0.0, 0.5, 0.01) var control_lock_duration: float = 0.12

var _control_lock_remaining: float = 0.0
var _owns_movement_override: bool = false

func _can_activate() -> bool:
	if not super._can_activate():
		return false
	if not is_instance_valid(owner_player):
		return false
	if not owner_player.is_multiplayer_authority() or not owner_player.spawn_confirmed:
		return false
	if owner_player.movement_override:
		return false
	return true

func _activate():
	var backward := owner_player.global_basis.z
	backward.y = 0.0
	if backward.length_squared() < 0.0001:
		var yaw := owner_player.global_rotation.y
		backward = Vector3(sin(yaw), 0.0, cos(yaw))
	backward = backward.normalized()

	owner_player.velocity.x += backward.x * horizontal_impulse
	owner_player.velocity.z += backward.z * horizontal_impulse
	owner_player.velocity.y = maxf(owner_player.velocity.y, 0.0) + upward_impulse

	_control_lock_remaining = control_lock_duration
	if _control_lock_remaining > 0.0:
		_owns_movement_override = true
		owner_player.movement_override = true

func physics_update(delta: float):
	if not _owns_movement_override:
		return
	if not is_instance_valid(owner_player):
		_owns_movement_override = false
		return

	_control_lock_remaining = maxf(_control_lock_remaining - delta, 0.0)
	if _control_lock_remaining == 0.0:
		_release_movement_override()

func cancel():
	_release_movement_override()

func _release_movement_override():
	if _owns_movement_override and is_instance_valid(owner_player):
		owner_player.movement_override = false
	_owns_movement_override = false
	_control_lock_remaining = 0.0
