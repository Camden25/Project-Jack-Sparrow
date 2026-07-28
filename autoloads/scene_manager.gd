extends Node

signal scene_loaded(scene: Node)

var scene_viewport: SubViewport
var current_scene: Node = null

func _ready():
	scene_viewport = get_tree().get_root().get_node("Root/SceneContainer/SubViewport")

func goto_scene(path: String):
	if current_scene:
		current_scene.queue_free()
		await get_tree().process_frame
	
	var new_scene = load(path).instantiate()
	scene_viewport.add_child(new_scene)
	current_scene = new_scene
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
