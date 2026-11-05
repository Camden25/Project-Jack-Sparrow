extends Projectile
class_name SmokeCanisters

@export var smoke_duration: float = 5.0
@export var smoke_radius: float = 4.0

var pending_origin: Vector3
var pending_impulse: Vector3

var has_landed: bool = false

func init_from_data(data: Dictionary):
	super.init_from_data(data)
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
	broadcast_visual_launch(
		"smoke_canister",
		pending_origin,
		pending_impulse / maxf(mass, 0.001),
		Vector3.DOWN * gravity_scale * float(ProjectSettings.get_setting("physics/3d/default_gravity")),
		lifetime
	)

func _on_body_entered(body: Node):
	if not multiplayer.is_server() or has_landed:
		return
	if body is CharacterBody3D:
		return
	has_landed = true
	freeze = true
	broadcast_visual_impact(global_position, Vector3.UP)
	var events = SceneManager.get_projectile_events()
	if events:
		events.broadcast_smoke_deployed(global_position, smoke_duration, smoke_radius)
	await get_tree().create_timer(smoke_duration).timeout
	if is_instance_valid(self):
		broadcast_visual_finished()
		queue_free()
