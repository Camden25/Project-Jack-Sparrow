extends Projectile
class_name AnchorProjectile

var _ability_node: DropAnchorAbility = null
var _pending_origin: Vector3 = Vector3.ZERO
var _spawn_height: float = 0.0

const ANCHOR_FALL_SPEED: float = 60.0

func init_from_data(data: Dictionary):
	shooter_id = data.get("shooter_id", -1)
	_pending_origin = data.get("origin", Vector3.ZERO)
	_spawn_height = _pending_origin.y

func _ready():
	global_position = _pending_origin
	
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	
	if not multiplayer.is_server():
		return
	
	var players_node = SceneManager.get_players_node()
	if players_node:
		var shooter = players_node.get_node_or_null(str(shooter_id))
		if shooter:
			var abilities = shooter.get_node_or_null("Abilities")
			if abilities:
				for child in abilities.get_children():
					if child is DropAnchorAbility:
						_ability_node = child
						break
	
	linear_velocity = Vector3(0, -ANCHOR_FALL_SPEED, 0)

func _physics_process(_delta: float):
	if not multiplayer.is_server():
		return
	linear_velocity.x = 0
	linear_velocity.z = 0

func _on_body_entered(body: Node):
	if not multiplayer.is_server():
		return
	if body is CharacterBody3D:
		return
	
	var drop_height = _spawn_height - global_position.y
	drop_height = maxf(drop_height, 0.0)
	
	var victims = []
	var players_node = SceneManager.get_players_node()
	if players_node:
		for player in players_node.get_children():
			if not player is CharacterBody3D:
				continue
			if player.get_multiplayer_authority() == shooter_id:
				continue
			if PlayerManager.is_same_team(shooter_id, player.get_multiplayer_authority()):
				continue
			if global_position.distance_to(player.global_position) <= 3.0:
				victims.append(player.get_multiplayer_authority())
	
	freeze = true
	linear_velocity = Vector3.ZERO
	
	if _ability_node:
		_ability_node.notify_anchor_landed(global_position, victims, drop_height)
	
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(self):
		queue_free()
