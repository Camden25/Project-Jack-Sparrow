extends Node

signal health_changed(new_health: int)
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
		MatchEvents.confirm_kill.rpc(attacker_peer_id, get_parent().get_multiplayer_authority())
		emit_signal("player_died", get_parent().get_multiplayer_authority())

func apply_healing(amount: int, healer_peer_id: int):
	if not multiplayer.is_server():
		return
	health = min(MAX_HEALTH, health + amount)
	_sync_health.rpc(health)
	#if health <= 0:
		#emit_signal("player_died", get_parent().get_multiplayer_authority())

@rpc("authority", "call_local", "reliable")
func _sync_health(new_health: int):
	health = new_health
	if get_parent().get_multiplayer_authority() == NetworkManager.get_my_peer_id():
		set_health_ui()
	emit_signal("health_changed", new_health)

func set_health_ui() -> void:
	var ui = get_tree().get_first_node_in_group("UI")
	if ui == null:
		print("no ui node")
		return
	ui.set_health_label(health, MAX_HEALTH)
