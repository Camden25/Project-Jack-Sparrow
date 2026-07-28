extends Node3D

@rpc("authority", "call_local", "unreliable")
func spawn_tracer(origin: Vector3, direction: Vector3):
	var tracer = preload("res://weapons/scenes/tracer.tscn").instantiate()
	tracer.start_pos = origin
	tracer.direction = direction
	add_child(tracer)
