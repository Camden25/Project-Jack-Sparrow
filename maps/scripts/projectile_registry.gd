extends Node

var _registry: Dictionary = {
	"smoke_canister" : preload("res://heroes/ex_navy_officer/abilities/smoke_canister/scenes/smoke_canister_projectile.tscn"),
	"anchor": preload("res://heroes/octopus_in_a_barrel/abilities/drop_anchor/scenes/anchor_projectile.tscn")
	}

func register(key: String, scene: PackedScene):
	_registry[key] = scene

func get_scene(key: String) -> PackedScene:
	return _registry.get(key)
