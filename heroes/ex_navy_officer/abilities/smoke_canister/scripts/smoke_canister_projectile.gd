extends Projectile
class_name SmokeCanisters

@export var smoke_duration: float = 5.0
@export var smoke_radius: float = 4.0

var pending_origin: Vector3
var pending_impulse: Vector3

var has_landed: bool = false

func init_from_data(data: Dictionary):
	pending_origin = data.get("origin", Vector3.ZERO)
	pending_impulse = data.get("impulse", Vector3.ZERO)
	smoke_duration = data.get("duration", 6.0)
	smoke_radius = data.get("radius", 4.0)
	shooter_id = data.get("shooter_id", -1)

func _ready():
	global_position = pending_origin
	apply_impulse(pending_impulse)
	
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node):
	if has_landed:
		return
	if body is CharacterBody3D:
		return
	has_landed = true
	freeze = true
	if not multiplayer.is_server():
		return
	_deploy_smoke.rpc(global_position, smoke_duration, smoke_radius)

@rpc("authority", "call_local", "reliable")
func _deploy_smoke(pos: Vector3, duration: float, radius: float):
	print("Smoke deployed at ", pos, " radius ", radius, " duration ", duration)
	var smoke_effect = preload("res://heroes/ex_navy_officer/abilities/smoke_canister/scenes/smoke_effect.tscn").instantiate()
	smoke_effect.duration = duration
	smoke_effect.radius = radius
	add_child(smoke_effect)
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		queue_free()
