extends Weapon
class_name ProjectileWeaponBase

@export var projectile_key: String = ""
@export var muzzle_point_path: NodePath
@export var projectile_speed: float = 30.0
@export var projectile_gravity: Vector3 = Vector3.DOWN * 9.8
@export var projectile_lifetime: float = 10.0
@export_range(0.0, 180.0, 1.0) var max_aim_deviation_degrees: float = 75.0
@export var projectile_data: Dictionary = {}

var muzzle: Node3D

var _server_ammo: int = 0
var _server_next_fire_time_msec: int = 0
var _server_reload_ends_at_msec: int = 0
var _next_fire_request_id: int = 0
var _server_last_fire_request_id: int = -1

func setup(player: HeroBase):
	super.setup(player)
	_server_ammo = current_ammo
	if not muzzle_point_path.is_empty():
		muzzle = owner_player.get_node_or_null(muzzle_point_path) as Node3D

func try_fire():
	if (
		not data
		or projectile_key.is_empty()
		or not is_finite(projectile_speed)
		or projectile_speed <= 0.0
		or not is_finite(projectile_lifetime)
		or projectile_lifetime <= 0.0
		or not projectile_gravity.is_finite()
	):
		push_error("ProjectileWeaponBase requires weapon data, a registered projectile key, and valid projectile physics values")
		return
	var registry = SceneManager.get_projectile_registry()
	if not registry or not registry.get_scene(projectile_key):
		push_error("ProjectileWeaponBase projectile key is not registered: " + projectile_key)
		return
	super.try_fire()

func _fire():
	if not is_instance_valid(owner_player):
		return

	var direction := _get_fire_direction()
	var request_id := _next_fire_request_id
	_next_fire_request_id += 1
	if multiplayer.is_server():
		_server_fire(multiplayer.get_unique_id(), request_id, direction)
	else:
		_request_server_fire.rpc_id(1, request_id, direction)

func _get_fire_direction() -> Vector3:
	var camera := owner_player.get_node_or_null("Head/Camera3D") as Camera3D
	if not camera:
		push_error("ProjectileWeaponBase could not find the owner's camera")
		return Vector3.ZERO
	return -camera.global_basis.z.normalized()

func reload():
	if is_reloading or not data or current_ammo == data.max_ammo:
		return

	if multiplayer.is_server():
		_server_start_reload(multiplayer.get_unique_id())
	else:
		_request_server_reload.rpc_id(1)
	super.reload()

@rpc("any_peer", "call_remote", "reliable")
func _request_server_fire(request_id: int, direction: Vector3):
	if not multiplayer.is_server():
		return
	_server_fire(multiplayer.get_remote_sender_id(), request_id, direction)

@rpc("any_peer", "call_remote", "reliable")
func _request_server_reload():
	if not multiplayer.is_server():
		return
	_server_start_reload(multiplayer.get_remote_sender_id())

func _server_fire(shooter_id: int, request_id: int, requested_direction: Vector3):
	if not multiplayer.is_server() or not data or not is_instance_valid(owner_player):
		return
	if shooter_id != owner_player.get_multiplayer_authority():
		return
	if request_id <= _server_last_fire_request_id:
		return
	_server_last_fire_request_id = request_id
	if not requested_direction.is_finite() or requested_direction.length_squared() < 0.0001:
		return
	if owner_player.get_weapon(data.slot) != self:
		return

	var health := owner_player.get_node_or_null("PlayerHealth") as PlayerHealth
	if health and health.health <= 0:
		return

	var now_msec := Time.get_ticks_msec()
	_refresh_server_ammo(now_msec)
	if now_msec < _server_next_fire_time_msec or _server_reload_ends_at_msec > now_msec or _server_ammo <= 0:
		return

	var direction := requested_direction.normalized()
	var camera := owner_player.get_node_or_null("Head/Camera3D") as Camera3D
	if not camera:
		push_error("ProjectileWeaponBase could not find the server owner's camera")
		return

	var server_aim := -camera.global_basis.z.normalized()
	var minimum_aim_dot := cos(deg_to_rad(max_aim_deviation_degrees))
	if direction.dot(server_aim) < minimum_aim_dot:
		return

	var origin := camera.global_position
	if is_instance_valid(muzzle) and muzzle.is_inside_tree():
		origin = muzzle.global_position

	var world = SceneManager.get_world()
	if not world:
		push_error("ProjectileWeaponBase could not find the current World")
		return

	var spawn_data := projectile_data.duplicate(true)
	spawn_data["shooter_id"] = shooter_id
	spawn_data["origin"] = origin
	spawn_data["initial_velocity"] = direction * projectile_speed
	spawn_data["gravity"] = projectile_gravity
	spawn_data["lifetime"] = projectile_lifetime
	spawn_data["damage"] = data.damage

	var projectile_id: int = world.spawn_projectile(projectile_key, spawn_data)
	if projectile_id < 0:
		return

	_server_ammo -= 1
	_server_next_fire_time_msec = now_msec + maxi(roundi(data.fire_rate * 1000.0), 1)
	if _server_ammo == 0:
		_server_start_reload(shooter_id)

func _server_start_reload(requester_id: int):
	if not multiplayer.is_server() or not data or not is_instance_valid(owner_player):
		return
	if requester_id != owner_player.get_multiplayer_authority():
		return

	var now_msec := Time.get_ticks_msec()
	_refresh_server_ammo(now_msec)
	if _server_ammo >= data.max_ammo or _server_reload_ends_at_msec > now_msec:
		return
	_server_reload_ends_at_msec = now_msec + maxi(roundi(data.reload_time * 1000.0), 1)

func _refresh_server_ammo(now_msec: int):
	if _server_reload_ends_at_msec > 0 and now_msec >= _server_reload_ends_at_msec:
		_server_ammo = data.max_ammo
		_server_reload_ends_at_msec = 0
