extends Node

signal hit_confirmed(shooter_id: int, target_peer_id: int)
signal player_killed(killer_id: int, victim_id: int)

@rpc("authority", "call_local", "unreliable")
func confirm_hit(shooter_id: int, target_peer_id: int):
	emit_signal("hit_confirmed", shooter_id, target_peer_id)

@rpc("authority", "call_local", "reliable")
func confirm_kill(killer_id: int, victim_id: int):
	emit_signal("player_killed", killer_id, victim_id)
