extends Node3D

@export var speed: float = 200.0
@export var lifetime: float = 0.5
@export var start_pos: Vector3
@export var direction: Vector3

var distance_traveled: float = 0.0
var max_distance: float

func _ready():
	global_position = start_pos
	look_at(start_pos + direction)
	max_distance = speed * lifetime
	
	# Auto cleanup
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _process(delta: float):
	var move = direction * speed * delta
	global_position += move
	distance_traveled += move.length()
	if distance_traveled >= max_distance:
		queue_free()
