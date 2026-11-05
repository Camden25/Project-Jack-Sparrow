extends Node
class_name ProjectileEventService

const PROJECTILE_VISUAL_SCRIPT = preload("res://maps/scripts/projectile_visual.gd")
const SMOKE_EFFECT_SCENE = preload("res://heroes/ex_navy_officer/abilities/smoke_canister/scenes/smoke_effect.tscn")
const FLARE_SCENE = preload("res://heroes/ex_navy_officer/abilities/volley/scenes/flare.tscn")
const VOLLEY_SHOT_SCENE = preload("res://heroes/ex_navy_officer/abilities/volley/scenes/volley_shot.tscn")

@onready var projectile_registry: Node = get_parent().get_node("ProjectileRegistry")
@onready var projectiles_node: Node3D = get_parent().get_node("Projectiles")
@onready var visuals_node: Node3D = $ProjectileVisuals

var _next_projectile_id: int = 1
var _client_projectiles: Dictionary = {}

func _enter_tree():
	set_multiplayer_authority(1)

func spawn_authoritative(key: String, data: Dictionary) -> int:
	if not multiplayer.is_server():
		push_error("Only the server can spawn gameplay projectiles")
		return -1

	var scene: PackedScene = projectile_registry.get_scene(key)
	if not scene:
		push_error("No projectile registered for key: " + key)
		return -1

	var projectile = scene.instantiate()
	if not projectile is Projectile:
		projectile.free()
		push_error("Registered scene is not a Projectile: " + key)
		return -1

	var projectile_id = _next_projectile_id
	_next_projectile_id += 1
	var spawn_data = data.duplicate()
	spawn_data["projectile_id"] = projectile_id
	projectile.name = key + "_" + str(projectile_id)
	projectile.init_from_data(spawn_data)
	projectiles_node.add_child(projectile)
	return projectile_id

func broadcast_launch(
	projectile_id: int,
	key: String,
	origin: Vector3,
	initial_velocity: Vector3,
	gravity: Vector3,
	lifetime: float
):
	if not multiplayer.is_server():
		return
	_rpc_launch_visual.rpc(projectile_id, key, origin, initial_velocity, gravity, lifetime)

func broadcast_impact(projectile_id: int, position: Vector3, normal: Vector3, linger_seconds: float):
	if not multiplayer.is_server():
		return
	_rpc_impact_visual.rpc(projectile_id, position, normal, linger_seconds)

func broadcast_finished(projectile_id: int):
	if not multiplayer.is_server():
		return
	_rpc_finish_visual.rpc(projectile_id)

func broadcast_smoke_deployed(position: Vector3, duration: float, radius: float):
	if not multiplayer.is_server():
		return
	_spawn_smoke_effect(position, duration, radius)
	_rpc_smoke_deployed.rpc(position, duration, radius)

func broadcast_effect(key: String, position: Vector3, lifetime: float):
	if not multiplayer.is_server():
		return
	_spawn_one_shot_visual(key, position, lifetime)
	_rpc_spawn_effect.rpc(key, position, lifetime)

@rpc("authority", "call_remote", "reliable")
func _rpc_launch_visual(
	projectile_id: int,
	key: String,
	origin: Vector3,
	initial_velocity: Vector3,
	gravity: Vector3,
	lifetime: float
):
	if _client_projectiles.has(projectile_id):
		return
	if not projectile_registry or not projectile_registry.get_scene(key):
		push_error("ProjectileEvents: Unknown projectile key: " + key)
		return

	var visual: ProjectileVisual = PROJECTILE_VISUAL_SCRIPT.new()
	visual.configure(projectile_id, key, origin, initial_velocity, gravity, lifetime)
	visual.visual_expired.connect(_on_client_projectile_expired)
	visuals_node.add_child(visual)
	_client_projectiles[projectile_id] = visual

@rpc("authority", "call_remote", "reliable")
func _rpc_impact_visual(projectile_id: int, position: Vector3, _normal: Vector3, linger_seconds: float):
	var visual: Variant = _client_projectiles.get(projectile_id)
	if is_instance_valid(visual):
		if linger_seconds > 0.0:
			visual.stop_at(position, linger_seconds)
		else:
			_remove_client_projectile(projectile_id)

@rpc("authority", "call_remote", "reliable")
func _rpc_finish_visual(projectile_id: int):
	_remove_client_projectile(projectile_id)

@rpc("authority", "call_remote", "reliable")
func _rpc_smoke_deployed(position: Vector3, duration: float, radius: float):
	_spawn_smoke_effect(position, duration, radius)

@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_effect(key: String, position: Vector3, lifetime: float):
	_spawn_one_shot_visual(key, position, lifetime)

func _remove_client_projectile(projectile_id: int):
	var visual: Variant = _client_projectiles.get(projectile_id)
	_client_projectiles.erase(projectile_id)
	if not is_instance_valid(visual):
		return
	visual.queue_free()

func _on_client_projectile_expired(projectile_id: int):
	_client_projectiles.erase(projectile_id)

func _spawn_smoke_effect(position: Vector3, duration: float, radius: float):
	var effects_manager = get_parent().get_node_or_null("Effects")
	if not effects_manager:
		push_error("ProjectileEvents: World/Effects is missing")
		return

	var smoke_effect = SMOKE_EFFECT_SCENE.instantiate()
	smoke_effect.duration = duration
	smoke_effect.radius = radius
	effects_manager.add_child(smoke_effect)
	smoke_effect.global_position = position

func _spawn_one_shot_visual(key: String, position: Vector3, lifetime: float):
	var scene: PackedScene
	match key:
		"volley_flare":
			scene = FLARE_SCENE
		"volley_shot":
			scene = VOLLEY_SHOT_SCENE
		_:
			push_error("ProjectileEvents: Unknown effect key: " + key)
			return

	var effects_manager = get_parent().get_node_or_null("Effects")
	if not effects_manager:
		push_error("ProjectileEvents: World/Effects is missing")
		return

	var effect = scene.instantiate()
	effects_manager.add_child(effect)
	effect.global_position = position
	get_tree().create_timer(lifetime).timeout.connect(effect.queue_free)
