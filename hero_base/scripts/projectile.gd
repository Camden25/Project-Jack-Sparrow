extends RigidBody3D
class_name Projectile

@export var lifetime: float = 10.0
@export var damage: int = 0

var shooter_id: int = -1
var projectile_id: int = -1
var _lifetime_timer: float = 0.0
var _finished: bool = false

signal landed(position: Vector3)
signal expired

func init_from_data(data: Dictionary):
	projectile_id = data.get("projectile_id", -1)

func launch(origin: Vector3, impulse: Vector3, from_shooter_id: int):
	global_position = origin
	shooter_id = from_shooter_id
	apply_impulse(impulse)

func broadcast_visual_launch(
	key: String,
	origin: Vector3,
	initial_velocity: Vector3,
	gravity: Vector3,
	visual_lifetime: float = lifetime
):
	if not multiplayer.is_server():
		return
	var events = SceneManager.get_projectile_events()
	if events:
		events.broadcast_launch(projectile_id, key, origin, initial_velocity, gravity, visual_lifetime)

func broadcast_visual_impact(position: Vector3, normal: Vector3, linger_seconds: float = 0.0):
	if not multiplayer.is_server() or _finished:
		return
	_finished = true
	var events = SceneManager.get_projectile_events()
	if events:
		events.broadcast_impact(projectile_id, position, normal, linger_seconds)

func broadcast_visual_finished():
	if not multiplayer.is_server() or _finished:
		return
	_finished = true
	var events = SceneManager.get_projectile_events()
	if events:
		events.broadcast_finished(projectile_id)

func _physics_process(delta: float):
	if not multiplayer.is_server() or _finished:
		return
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		broadcast_visual_finished()
		emit_signal("expired")
		queue_free()

@warning_ignore("unused_parameter")
func _on_body_entered(body: Node):
	emit_signal("landed", global_position)
