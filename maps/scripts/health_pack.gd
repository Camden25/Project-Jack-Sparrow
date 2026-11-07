extends Area3D
class_name HealthPack

@export_range(1, 100) var heal_amount: int = 40
@export_range(0.0, 120.0, 0.5) var respawn_delay: float = 10.0

@onready var visuals: Node3D = $Visuals
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _available: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server() or not _available:
		return

	var player := body as Player
	if not player:
		return

	var health := player.get_node_or_null("PlayerHealth") as PlayerHealth
	if not health:
		return

	var healed_amount := health.apply_healing(heal_amount, player.get_multiplayer_authority())
	if healed_amount <= 0:
		return

	_set_available.rpc(false)
	_respawn_after_delay()

func _respawn_after_delay() -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if is_instance_valid(self):
		_set_available.rpc(true)

@rpc("authority", "call_local", "reliable")
func _set_available(is_available: bool) -> void:
	_available = is_available
	visuals.visible = is_available
	collision_shape.set_deferred("disabled", not is_available)
	monitoring = is_available
