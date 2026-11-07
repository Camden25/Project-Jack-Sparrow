extends PlayerHealth
class_name PracticeDummyHealth

signal dummy_defeated

func apply_damage(amount: int, _attacker_peer_id: int) -> void:
	if not multiplayer.is_server() or health <= 0:
		return

	health = max(0, health - maxi(amount, 0))
	_sync_health.rpc(health)
	if health == 0:
		dummy_defeated.emit()
