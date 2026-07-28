extends Node3D

@export var start_pos: Vector3
@export var direction: Vector3
@export var speed: float = 200.0
@export var lifetime: float = 0.3
@export var tracer_length: float = 3.0
@export var tracer_width: float = 0.03

var distance_traveled: float = 0.0
var max_distance: float = 0.0
var active: bool = false
var mesh_instance: MeshInstance3D

func _ready():
	global_position = start_pos
	if direction != Vector3.ZERO:
		look_at(start_pos + direction)
	max_distance = speed * lifetime
	
	_build_mesh()
	
	active = true
	
	if multiplayer.is_server():
		await get_tree().create_timer(lifetime + 0.2).timeout
		if is_instance_valid(self):
			queue_free()

func _build_mesh():
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	var capsule = CapsuleMesh.new()
	capsule.radius = tracer_width
	capsule.height = tracer_length
	mesh_instance.mesh = capsule
	
	# Rotate so capsule points forward
	mesh_instance.rotation_degrees.x = 90
	# Offset so tracer trails behind
	mesh_instance.position.z = tracer_length / 2.0
	
	# Bright emissive material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.5)   # warm yellow
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.3)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.set_surface_override_material(0, mat)

func _process(delta: float):
	if not active:
		return
	var move = direction * speed * delta
	global_position += move
	distance_traveled += move.length()
	if distance_traveled >= max_distance:
		active = false
		if is_instance_valid(self):
			queue_free()
