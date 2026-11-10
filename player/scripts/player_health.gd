extends Node
class_name PlayerHealth

signal health_changed(new_health: int)
@warning_ignore("unused_signal")
signal player_died(peer_id: int)

@export var MAX_HEALTH = 100

var health: float = MAX_HEALTH

func _ready() -> void:
	health = MAX_HEALTH

func _enter_tree() -> void:
	set_multiplayer_authority(1)

func apply_damage(amount: float, attacker_peer_id: int):
	if not multiplayer.is_server():
		return
	if health <= 0:
		return
	health = max(0, health - amount)
	_sync_health.rpc(health)
	if health <= 0:
		emit_signal("player_died", get_parent().get_multiplayer_authority())
		MatchEvents.confirm_kill.rpc(attacker_peer_id, get_parent().get_multiplayer_authority())

func apply_healing(amount: float, healer_peer_id: int) -> float:
	if not multiplayer.is_server():
		return 0
	if health <= 0 or amount <= 0:
		return 0

	var healed_amount: float = min(amount, MAX_HEALTH - health)
	if healed_amount <= 0:
		return 0

	health += healed_amount
	_sync_health.rpc(health)
	var healer: Node
	var healed_player := get_parent()
	if (
		healed_player is Player
		and healed_player.get_multiplayer_authority() == healer_peer_id
	):
		healer = healed_player
	elif not healed_player is PracticeDummy:
		var players := SceneManager.get_players_node()
		if players:
			healer = players.get_node_or_null(str(healer_peer_id))
	if healer and healer.has_signal("healing_done"):
		healer.emit_signal("healing_done", healed_amount)
	return healed_amount

func set_health(amount: float):
	health = amount
	health = clamp(amount, 0, MAX_HEALTH)
	emit_signal("health_changed", health)
	_sync_health.rpc(health)

@rpc("authority", "call_local", "reliable")
func _sync_health(new_health: float):
	health = new_health
	emit_signal("health_changed", new_health)
