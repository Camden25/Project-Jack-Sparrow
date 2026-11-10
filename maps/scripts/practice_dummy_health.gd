extends PlayerHealth
class_name PracticeDummyHealth

signal dummy_defeated

func apply_damage(amount: float, _attacker_peer_id: int) -> void:
	if not multiplayer.is_server() or health <= 0:
		return
	var dummy := get_parent() as PracticeDummy
	if dummy and dummy.is_ally:
		return
	
	health = max(0, health - max(amount, 0))
	_sync_health.rpc(health)
	if health == 0:
		dummy_defeated.emit()

func apply_forced_damage(amount: float, _attacker_peer_id: int) -> void:
	if not multiplayer.is_server() or health <= 0:
		return
	
	health = max(0, health - max(amount, 0))
	_sync_health.rpc(health)
	if health == 0:
		dummy_defeated.emit()
