extends CharacterBody3D
class_name PracticeDummy

const RESPAWN_DELAY := 3.0
const VISIBLE_OUTLINE_SHADER = preload("res://player/shaders/visible_outline.gdshader")
const ENEMY_OUTLINE_COLOR := Color(1.0, 0.08, 0.08)

@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var health_component: PracticeDummyHealth = $PlayerHealth
@onready var world_health_bar: Node3D = $WorldHealthBar

var _outline_mesh: MeshInstance3D

func _ready() -> void:
	_setup_outline()
	health_component.health_changed.connect(_on_health_changed)
	health_component.dummy_defeated.connect(_on_dummy_defeated)
	world_health_bar.call("setup", "Practice Dummy", PlayerManager.Team.NONE)
	_on_health_changed(health_component.health)

func _setup_outline() -> void:
	_outline_mesh = body_mesh.duplicate() as MeshInstance3D
	_outline_mesh.name = "EnemyOutline"
	var outline_material := ShaderMaterial.new()
	outline_material.shader = VISIBLE_OUTLINE_SHADER
	outline_material.set_shader_parameter("outline_color", ENEMY_OUTLINE_COLOR)
	outline_material.set_shader_parameter("outline_width", 0.045)
	_outline_mesh.material_override = outline_material
	_outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body_mesh.add_sibling(_outline_mesh)

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
	body_mesh.visible = active
	_outline_mesh.visible = active
	collision_shape.disabled = not active
	world_health_bar.visible = active
