@tool
extends HeroBase

func _enter_tree():
	if not Engine.is_editor_hint():
		return
	if not get_parent():
		return
	_setup_hero_nodes()

func _setup_hero_nodes():
	# Don't add if nodes already exist
	if get_node_or_null("Head"):
		return
	
	print("HeroBase: auto-setting up hero nodes...")
	
	# Head + Camera
	var head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.6, 0)
	add_child(head)
	head.owner = get_tree().edited_scene_root
	
	var camera = Camera3D.new()
	camera.name = "Camera3D"
	head.add_child(camera)
	camera.owner = get_tree().edited_scene_root
	
	var weapon_holder = Node3D.new()
	weapon_holder.name = "WeaponHolder"
	head.add_child(weapon_holder)
	weapon_holder.owner = get_tree().edited_scene_root
	
	# Collision
	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col.shape = capsule
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	col.owner = get_tree().edited_scene_root
	
	# Mesh placeholder
	var mesh = MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.radius = 0.4
	capsule_mesh.height = 1.8
	mesh.mesh = capsule_mesh
	mesh.position = Vector3(0, 0.9, 0)
	add_child(mesh)
	mesh.owner = get_tree().edited_scene_root
	
	# Abilities node
	var abilities = Node.new()
	abilities.name = "Abilities"
	add_child(abilities)
	abilities.owner = get_tree().edited_scene_root
	
	# MultiplayerSynchronizer
	var sync = MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSynchronizer"
	add_child(sync)
	sync.owner = get_tree().edited_scene_root
	
	# Support nodes
	var interp = Node.new()
	interp.name = "InterpolationController"
	add_child(interp)
	interp.owner = get_tree().edited_scene_root
	
	var lag = Node.new()
	lag.name = "LagCompensationBuffer"
	add_child(lag)
	lag.owner = get_tree().edited_scene_root
	
	var health = Node.new()
	health.name = "PlayerHealth"
	add_child(health)
	health.owner = get_tree().edited_scene_root
	
	var whb = Node3D.new()
	whb.name = "WorldHealthBar"
	add_child(whb)
	whb.owner = get_tree().edited_scene_root
	
	print("HeroBase: node setup complete.")
