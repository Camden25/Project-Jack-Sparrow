extends Node
class_name Weapon

@export var data: WeaponData

var owner_player: HeroBase = null
var current_ammo: int = 0
var is_reloading: bool = false
var _fire_timer: float = 0.0
var _can_fire: bool = true

signal ammo_changed(current: int, maximum: int)
signal reload_started
signal reload_finished

@export var viewmodel_path: NodePath
@export var world_mesh_path: NodePath

var _viewmodel: Node3D = null
var _world_mesh: Node3D = null

func setup(player: HeroBase):
	owner_player = player
	if data:
		current_ammo = data.max_ammo
	
	if viewmodel_path:
		_viewmodel = owner_player.get_node_or_null(viewmodel_path)
	if world_mesh_path:
		_world_mesh = owner_player.get_node_or_null(world_mesh_path)
	_set_visible(false)

func try_fire():
	if not _can_fire or is_reloading or current_ammo <= 0:
		return
	_can_fire = false
	current_ammo -= 1
	emit_signal("ammo_changed", current_ammo, data.max_ammo)
	_fire()
	if current_ammo == 0:
		reload()

func _fire():
	pass

func reload():
	if is_reloading or not data or current_ammo == data.max_ammo:
		return
	is_reloading = true
	emit_signal("reload_started")
	await get_tree().create_timer(data.reload_time).timeout
	if not is_instance_valid(self):
		return
	current_ammo = data.max_ammo
	is_reloading = false
	_can_fire = true
	emit_signal("ammo_changed", current_ammo, data.max_ammo)
	emit_signal("reload_finished")

func _process(delta: float):
	if not _can_fire:
		_fire_timer += delta
		if data and _fire_timer >= data.fire_rate:
			_fire_timer = 0.0
			_can_fire = true

func set_weapon_visible(visible: bool):
	_set_visible(visible)

func _set_visible(v: bool):
	if _viewmodel:
		_viewmodel.visible = v
	if _world_mesh:
		_world_mesh.visible = v
