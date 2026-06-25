extends Ability
class_name SmokeCanisterAbility

@export var throw_force: float = 15.0
@export var smoke_duration: float = 6.0
@export var smoke_radius: float = 4.0

const SMOKE_SCENE = preload("res://heroes/ex_navy_officer/abilities/smoke_canister/scenes/smoke_effect.tscn")

func _activate():
	if not owner_player.is_multiplayer_authority():
		return
	_throw_canister.rpc_id(1,
		owner_player.get_node("Head/Camera3D").global_position,
		-owner_player.get_node("Head/Camera3D").global_basis.z * throw_force
	)

@rpc("any_peer", "call_remote", "reliable")
func _throw_canister(origin: Vector3, impulse: Vector3):
	if not multiplayer.is_server():
		return
	
	var smoke = SMOKE_SCENE.instantiate()
	smoke.duration = smoke_duration
	smoke.radius = smoke_radius
	smoke.launch_impulse = impulse
	
	var world = owner_player.get_tree().get_root().get_node_or_null("World")
	if world:
		world.get_node("Projectiles").add_child(smoke)
		smoke.global_position = origin
