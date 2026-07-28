extends Node
class_name LagCompensationBuffer

const BUFFER_DURATION = 0.6 # store 600ms of history
const TICK_RATE = 0.016 # ~60hz

var history: Array = [] # [{time, position, basis, collision_shape_transform}]
var owner_node: Player

func _enter_tree() -> void:
	set_multiplayer_authority(1)

func setup(player: Player):
	owner_node = player

func record():
	if not multiplayer.is_server():
		return
	
	history.append({
		"time": Time.get_ticks_msec() / 1000.0,
		"position": owner_node.global_position,
		"basis": owner_node.global_basis
	})
	
	# Prune old entries
	var cutoff = Time.get_ticks_msec() / 1000.0 - BUFFER_DURATION
	while history.size() > 0 and history[0].time < cutoff:
		history.pop_front()

func get_position_at(timestamp: float) -> Dictionary:
	if history.is_empty():
		return { "position": owner_node.global_position, "basis": owner_node.global_basis }
	
	# Find surrounding snapshots
	for i in range(history.size() - 1):
		var a = history[i]
		var b = history[i + 1]
		if a.time <= timestamp and b.time >= timestamp:
			var t = 0.0
			var range_t = b.time - a.time
			if range_t > 0:
				t = (timestamp - a.time) / range_t
			return {
				"position": a.position.lerp(b.position, t),
				"basis": a.basis
			}
	
	# Timestamp older than buffer — use oldest
	if timestamp < history[0].time:
		return { "position": history[0].position, "basis": history[0].basis }
	
	# Timestamp newer than buffer — use latest
	var latest = history[history.size() - 1]
	return { "position": latest.position, "basis": latest.basis }
