extends Node3D
class_name WeaponBase

# Override these in subclasses
@export var damage: int = 15
@export var fire_rate: float = 0.1 # seconds between shots
@export var max_ammo: int = 30
@export var reload_time: float = 1.5

var current_ammo: int = max_ammo
var can_fire: bool = true
var is_reloading: bool = false

signal fired
signal reloaded

func try_fire(origin: Vector3, direction: Vector3):
	if not can_fire or is_reloading or current_ammo <= 0:
		return
	can_fire = false
	current_ammo -= 1
	emit_signal("fired")
	_fire(origin, direction)
	await get_tree().create_timer(fire_rate).timeout
	can_fire = true

func _fire(origin: Vector3, direction: Vector3):
	pass  # override in subclass

func reload():
	if is_reloading or current_ammo == max_ammo:
		return
	is_reloading = true
	await get_tree().create_timer(reload_time).timeout
	current_ammo = max_ammo
	is_reloading = false
	emit_signal("reloaded")
