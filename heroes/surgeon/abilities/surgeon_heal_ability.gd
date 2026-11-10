extends Ability
class_name SurgeonHealAbility

var _server_next_use_time_msec: int = 0

func _can_use_on_server(sender_id: int) -> bool:
	if (
		not multiplayer.is_server()
		or not is_instance_valid(owner_player)
		or not data
		or sender_id != owner_player.get_multiplayer_authority()
		or owner_player.get_ability(data.slot) != self
	):
		return false

	var owner_health := owner_player.get_node_or_null("PlayerHealth") as PlayerHealth
	if owner_health and owner_health.health <= 0:
		return false

	var now_msec := Time.get_ticks_msec()
	return now_msec >= _server_next_use_time_msec

func _validate_server_use(sender_id: int) -> bool:
	if not _can_use_on_server(sender_id):
		return false
	var now_msec := Time.get_ticks_msec()
	_server_next_use_time_msec = now_msec + roundi(data.cooldown * 1000.0)
	return true

func _find_player_root(node: Node) -> Node:
	var current := node
	while current:
		if current is CharacterBody3D and current.get_node_or_null("PlayerHealth"):
			return current
		current = current.get_parent()
	return null

func _is_ally_target(target: Node) -> bool:
	if not target or target == owner_player:
		return false
	var is_ally := false
	if target is PracticeDummy:
		is_ally = target.is_ally
	elif target is Player:
		var owner_team := PlayerManager.get_team(owner_player.get_multiplayer_authority())
		is_ally = (
			owner_team != PlayerManager.Team.NONE
			and PlayerManager.get_team(target.get_multiplayer_authority()) == owner_team
		)
	if not is_ally:
		return false

	var health := target.get_node_or_null("PlayerHealth") as PlayerHealth
	return health != null and health.health > 0 and health.health < health.MAX_HEALTH

func _apply_healing(target: Node, amount: int) -> bool:
	if not multiplayer.is_server() or not _is_ally_target(target):
		return false
	var health := target.get_node_or_null("PlayerHealth") as PlayerHealth
	if not health:
		return false
	return health.apply_healing(amount, owner_player.get_multiplayer_authority()) > 0

func _get_players_and_dummies() -> Array[Node]:
	var targets: Array[Node] = []
	var players := SceneManager.get_players_node()
	if players:
		for player in players.get_children():
			targets.append(player)
	targets.append_array(get_tree().get_nodes_in_group("practice_dummies"))
	return targets
