extends Node3D
class_name SmokeEffect

var duration: float
var radius: float

func _ready() -> void:
	add_to_group("smoke_effects")
	$Timer.start(duration)
	#$FogVolume.size = Vector3(radius, radius, radius)
	$FogOutside.radius = radius / 2
	$FogInside.radius = radius / 2

func contains_position(position: Vector3) -> bool:
	var smoke_radius := radius / 2.0
	return global_position.distance_squared_to(position) <= smoke_radius * smoke_radius

func _on_timer_timeout() -> void:
	queue_free()
