extends Node3D

@export var start_pos: Vector3
@export var direction: Vector3
@export var speed: float = 200.0
@export var lifetime: float = 0.5

var distance_traveled: float = 0.0
var max_distance: float = 0.0
var active: bool = false

func _ready():
	global_position = start_pos
	if direction != Vector3.ZERO:
		look_at(start_pos + direction)
	max_distance = speed * lifetime
	active = true
	
	if multiplayer.is_server():
		await get_tree().create_timer(lifetime + 0.2).timeout
		queue_free()

func _process(delta: float):
	if not active:
		return
	var move = direction * speed * delta
	global_position += move
	distance_traveled += move.length()
	if distance_traveled >= max_distance:
		active = false
