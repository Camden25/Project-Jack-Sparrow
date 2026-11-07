extends Node3D
class_name ProjectileVisual

var projectile_id: int = -1
var projectile_key: String = ""
var velocity: Vector3 = Vector3.ZERO
var gravity: Vector3 = Vector3.ZERO
var lifetime: float = 10.0
var _elapsed: float = 0.0
var _is_impacted: bool = false

signal visual_expired(projectile_id: int)

func configure(id: int, key: String, origin: Vector3, initial_velocity: Vector3, gravity_vector: Vector3, max_lifetime: float):
	projectile_id = id
	projectile_key = key
	global_position = origin
	velocity = initial_velocity
	gravity = gravity_vector
	lifetime = max_lifetime

func stop_at(position: Vector3, linger_seconds: float):
	global_position = position
	velocity = Vector3.ZERO
	gravity = Vector3.ZERO
	lifetime = linger_seconds
	_elapsed = 0.0
	_is_impacted = true

func _ready():
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	var material := StandardMaterial3D.new()
	
	match projectile_key:
		"smoke_canister":
			sphere.radius = 0.1
			sphere.height = 0.2
			material.albedo_color = Color(0.25, 0.23, 0.2)
		"anchor":
			sphere.radius = 0.7
			sphere.height = 1.4
			material.albedo_color = Color(0.24, 0.22, 0.2)
		"cannonball":
			sphere.radius = 0.35
			sphere.height = 0.7
			material.albedo_color = Color(0.13, 0.12, 0.11)
			material.metallic = 0.55
			material.roughness = 0.45
	
	mesh_instance.mesh = sphere
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _process(delta: float):
	_elapsed += delta
	if _elapsed >= lifetime:
		visual_expired.emit(projectile_id)
		queue_free()
		return
	
	if _is_impacted:
		return
	
	velocity += gravity * delta
	global_position += velocity * delta
