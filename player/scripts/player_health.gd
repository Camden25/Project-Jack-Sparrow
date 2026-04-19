extends Node

signal health_changed(new_health: int)
@warning_ignore("unused_signal")
signal player_died(peer_id: int)

@export var MAX_HEALTH = 100

var health: int = MAX_HEALTH

func _enter_tree() -> void:
	set_multiplayer_authority(1)

func apply_damage(amount: int, attacker_peer_id: int):
	if not multiplayer.is_server():
		return
	health = max(0, health - amount)
	_sync_health.rpc(health)
	if health <= 0:
		var respawn_manager = get_tree().get_root().get_node_or_null("World/RespawnManager")
		if respawn_manager:
			respawn_manager.handle_player_death(
				get_parent().get_multiplayer_authority()
			)
		MatchEvents.confirm_kill.rpc(attacker_peer_id, get_parent().get_multiplayer_authority())

func apply_healing(amount: int, _healer_peer_id: int):
	if not multiplayer.is_server():
		return
	health = min(MAX_HEALTH, health + amount)
	_sync_health.rpc(health)
	#if health <= 0:
		#emit_signal("player_died", get_parent().get_multiplayer_authority())

func set_health(amount: int):
	if not multiplayer.is_server():
		return
	health = clamp(amount, 0, MAX_HEALTH)
	_sync_health.rpc(health)

@rpc("authority", "call_local", "reliable")
func _sync_health(new_health: int):
	health = new_health
	emit_signal("health_changed", new_health)
