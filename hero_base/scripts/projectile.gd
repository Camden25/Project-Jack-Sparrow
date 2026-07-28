extends RigidBody3D
class_name Projectile

@export var lifetime: float = 10.0
@export var damage: int = 0

var shooter_id: int = -1
var _lifetime_timer: float = 0.0

signal landed(position: Vector3)
signal expired

func init_from_data(data: Dictionary):
	pass # override in subclass

func launch(origin: Vector3, impulse: Vector3, from_shooter_id: int):
	global_position = origin
	shooter_id = from_shooter_id
	apply_impulse(impulse)

func _physics_process(delta: float):
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		emit_signal("expired")
		queue_free()

@warning_ignore("unused_parameter")
func _on_body_entered(body: Node):
	emit_signal("landed", global_position)
