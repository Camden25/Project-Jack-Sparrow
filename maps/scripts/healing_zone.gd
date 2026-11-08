extends Area3D
class_name HealingZone

@export_range(0.0, 100.0, 0.5) var healing_per_second: float = 20.0

var _targets_inside: Array[CharacterBody3D] = []
var _healing_remainders: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() == false:
		return
	if not multiplayer.is_server() or healing_per_second <= 0.0:
		return

	for index in range(_targets_inside.size() - 1, -1, -1):
		var target := _targets_inside[index]
		if not is_instance_valid(target):
			_targets_inside.remove_at(index)
			continue

		var health := target.get_node_or_null("PlayerHealth") as PlayerHealth
		if not health:
			_targets_inside.remove_at(index)
			_healing_remainders.erase(target.get_instance_id())
			continue

		var target_id := target.get_instance_id()
		var accumulated_healing: float = _healing_remainders.get(target_id, 0.0)
		accumulated_healing += healing_per_second * delta
		var heal_amount := floori(accumulated_healing)
		if heal_amount > 0:
			accumulated_healing -= heal_amount
			health.apply_healing(heal_amount, target.get_multiplayer_authority())
		_healing_remainders[target_id] = accumulated_healing

func _on_body_entered(body: Node3D) -> void:
	var target := body as CharacterBody3D
	if (
		target
		and target.get_node_or_null("PlayerHealth") is PlayerHealth
		and not _targets_inside.has(target)
	):
		_targets_inside.append(target)

func _on_body_exited(body: Node3D) -> void:
	var target := body as CharacterBody3D
	if target:
		_targets_inside.erase(target)
		_healing_remainders.erase(target.get_instance_id())
