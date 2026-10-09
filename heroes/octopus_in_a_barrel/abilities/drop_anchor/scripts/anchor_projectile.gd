extends Projectile
class_name AnchorProjectile

var _ability_node: DropAnchorAbility = null
var _pending_origin: Vector3 = Vector3.ZERO
var _spawn_height: float = 0.0
var _has_landed: bool = false
var _last_contact_normal: Vector3 = Vector3.UP

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
			for child in shooter.get_node_or_null("Abilities").get_children():
				if child is DropAnchorAbility:
					_ability_node = child
					break
	
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	linear_velocity = Vector3(0, -ANCHOR_FALL_SPEED, 0)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if state.get_contact_count() > 0:
		_last_contact_normal = state.get_contact_local_normal(0)

func _physics_process(_delta: float):
	if not multiplayer.is_server() or _has_landed:
		return
	linear_velocity = Vector3(0, -ANCHOR_FALL_SPEED, 0)

func _on_body_entered(body: Node):
	if not multiplayer.is_server() or _has_landed:
		return
	if body is CharacterBody3D:
		return
	if _last_contact_normal.dot(Vector3.UP) < 0.3:
		return
	
	_has_landed = true
	freeze = true
	linear_velocity = Vector3.ZERO
	
	var drop_height = maxf(_spawn_height - global_position.y, 0.0)
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
	
	if _ability_node:
		_ability_node.notify_anchor_landed(global_position, victims, drop_height)
	
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(self):
		queue_free()
