extends Node

signal scene_loaded(scene: Node)

var scene_viewport: SubViewport
var current_scene: Node = null

var _is_transitioning: bool = false

func _ready():
	scene_viewport = get_tree().get_root().get_node("Root/SceneContainer/SubViewport")

func goto_scene(path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	
	if current_scene:
		var old_scene = current_scene
		current_scene = null
		old_scene.queue_free()
	
	for child in scene_viewport.get_children():
		if is_instance_valid(child):
			child.queue_free()
	
	var new_scene = load(path).instantiate()
	scene_viewport.add_child(new_scene)
	current_scene = new_scene
	_is_transitioning = false
	emit_signal("scene_loaded", new_scene)

func get_current_scene() -> Node:
	return current_scene

func get_world() -> Node:
	var scene = get_current_scene()
	if scene and scene.name == "World":
		return scene
	return null

func get_players_node() -> Node:
	var world = get_world()
	if world:
		return world.get_node_or_null("Players")
	return null

func get_projectiles_node() -> Node:
	var world = get_world()
	if world:
		return world.get_node_or_null("Projectiles")
	return null

func get_effects_manager() -> Node:
	var world = get_world()
	if world:
		return world.get_node_or_null("Effects")
	return null

func get_projectile_registry() -> Node:
	var world = get_world()
	if world:
		return world.get_node_or_null("ProjectileRegistry")
	return null
