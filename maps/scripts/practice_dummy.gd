extends CharacterBody3D
class_name PracticeDummy

const RESPAWN_DELAY := 3.0
const VISIBLE_OUTLINE_SHADER = preload("res://player/shaders/visible_outline.gdshader")
const XRAY_OUTLINE_SHADER = preload("res://player/shaders/xray_outline.gdshader")
const ENEMY_OUTLINE_COLOR := Color(1.0, 0.08, 0.08)
const ALLY_OUTLINE_COLOR := Color(0.08, 0.35, 1.0)

@export var is_ally: bool = false
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var health_component: PracticeDummyHealth = $PlayerHealth
@onready var world_health_bar: Node3D = $WorldHealthBar

var _outline_mesh: MeshInstance3D
var _outline_material: ShaderMaterial
var _smoke_outline_mesh: MeshInstance3D
var _smoke_outline_visible := false
var _is_active := true

func _ready() -> void:
	_setup_outline()
	health_component.health_changed.connect(_on_health_changed)
	health_component.dummy_defeated.connect(_on_dummy_defeated)
	var dummy_name := "Ally Practice Dummy" if is_ally else "Practice Dummy"
	var dummy_team := PlayerManager.get_team(multiplayer.get_unique_id()) if is_ally else PlayerManager.Team.NONE
	world_health_bar.call("setup", dummy_name, dummy_team)
	_on_health_changed(health_component.health)

func _process(_delta: float) -> void:
	if not is_ally or not _is_active or not is_instance_valid(_outline_material):
		return

	var outline_shader := VISIBLE_OUTLINE_SHADER
	if not _is_visible_to_local_camera():
		outline_shader = XRAY_OUTLINE_SHADER
	if _outline_material.shader != outline_shader:
		_outline_material.shader = outline_shader

func _setup_outline() -> void:
	_outline_mesh = body_mesh.duplicate() as MeshInstance3D
	_outline_mesh.name = "AllyOutline" if is_ally else "EnemyOutline"
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = VISIBLE_OUTLINE_SHADER
	_outline_material.set_shader_parameter("outline_color", ALLY_OUTLINE_COLOR if is_ally else ENEMY_OUTLINE_COLOR)
	_outline_material.set_shader_parameter("outline_width", 0.045)
	_outline_mesh.material_override = _outline_material
	_outline_mesh.layers = body_mesh.layers
	_outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body_mesh.add_sibling(_outline_mesh)

	_smoke_outline_mesh = body_mesh.duplicate() as MeshInstance3D
	_smoke_outline_mesh.name = "SmokeOutline"
	var smoke_material := ShaderMaterial.new()
	smoke_material.shader = XRAY_OUTLINE_SHADER
	smoke_material.set_shader_parameter("outline_color", ENEMY_OUTLINE_COLOR)
	smoke_material.set_shader_parameter("outline_width", 0.06)
	_smoke_outline_mesh.material_override = smoke_material
	_smoke_outline_mesh.layers = body_mesh.layers
	_smoke_outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_smoke_outline_mesh.visible = false
	body_mesh.add_sibling(_smoke_outline_mesh)

func _is_visible_to_local_camera() -> bool:
	var local_camera := get_viewport().get_camera_3d()
	if not local_camera:
		return true

	var players_node := SceneManager.get_players_node()
	if not players_node:
		return true

	var local_player := players_node.get_node_or_null(str(multiplayer.get_unique_id()))
	var excluded_rids: Array[RID] = []
	if local_player is CollisionObject3D:
		excluded_rids.append(local_player.get_rid())

	for height in [0.45, 0.9, 1.35]:
		var query := PhysicsRayQueryParameters3D.create(
			local_camera.global_position,
			global_position + Vector3.UP * height
		)
		query.exclude = excluded_rids
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			return true

		var hit_node := result.get("collider") as Node
		while is_instance_valid(hit_node):
			if hit_node == self:
				return true
			hit_node = hit_node.get_parent()

	return false

func set_smoke_outline_visible(is_visible: bool) -> void:
	_smoke_outline_visible = is_visible
	if is_instance_valid(_smoke_outline_mesh):
		_smoke_outline_mesh.visible = is_visible and _is_active and not is_ally

func _on_health_changed(new_health: int) -> void:
	world_health_bar.call("update_health", new_health, health_component.MAX_HEALTH)

func _on_dummy_defeated() -> void:
	if not multiplayer.is_server():
		return

	_set_active.rpc(false)
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if not is_inside_tree():
		return

	health_component.set_health(health_component.MAX_HEALTH)
	_set_active.rpc(true)

@rpc("authority", "call_local", "reliable")
func _set_active(active: bool) -> void:
	_is_active = active
	body_mesh.visible = active
	_outline_mesh.visible = active
	_smoke_outline_mesh.visible = active and _smoke_outline_visible and not is_ally
	collision_shape.disabled = not active
	world_health_bar.visible = active
