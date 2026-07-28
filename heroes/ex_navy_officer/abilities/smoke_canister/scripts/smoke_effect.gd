extends Node3D

var duration: float
var radius: float

func _ready() -> void:
	$Timer.start(duration)
	$FogVolume.size = Vector3(radius, radius, radius)

func _on_timer_timeout() -> void:
	queue_free()
