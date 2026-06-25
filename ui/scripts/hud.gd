extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthContainer/HealthBar
@onready var health_label: Label = $HealthContainer/HealthLabel
@onready var ammo_label: Label = $AmmoContainer/AmmoLabel
@onready var cooldown_bar: ProgressBar = $AbilityCooldown/CooldownBar
@onready var cooldown_label: Label = $AbilityCooldown/CooldownLabel
@onready var control_point_progress_label: Label = $ControlPointProgress
@onready var death_label: Label = $DeathLabel
@onready var ping_label: Label = $PingLabel

var local_player: Player = null

func _ready():
	# Wait for world to spawn local player
	NetworkManager.player_connected.connect(_on_player_connected)
	MatchEvents.hit_confirmed.connect(_on_hit_confirmed)
	await get_tree().process_frame
	await get_tree().process_frame
	_on_player_connected(multiplayer.get_unique_id())
	hide()

func _on_player_connected(_peer_id: int):
	# Find our local player node
	await get_tree().process_frame
	var players_node = get_tree().get_root().get_node_or_null("World/Players")
	if not players_node:
		return
	
	var my_id = str(multiplayer.get_unique_id())
	local_player = players_node.get_node_or_null(my_id)
	if not local_player:
		return
	
	_connect_to_player(local_player)
	show()

func _connect_to_player(player: Player):
	# Health
	player.health_component.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health_component.health)
	
	# Ability cooldown
	player.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
	_on_dash_cooldown_changed(0.0, player.DASH_COOLDOWN)
	
	# Ammo — poll weapon directly since it can change
	# we'll update this in _process

func _process(_delta: float):
	if not local_player:
		return
	
	# Ammo
	var weapon_holder = local_player.get_node_or_null("Head/WeaponHolder")
	if weapon_holder and weapon_holder.get_child_count() > 0:
		var weapon = weapon_holder.get_child(0)
		ammo_label.text = str(weapon.current_ammo) + " / " + str(weapon.max_ammo)
	
	set_control_point_progress()
	set_ping_label()

func _on_health_changed(new_health: int):
	health_bar.value = new_health
	health_bar.max_value = 100
	health_label.text = str(new_health) + " HP"
	death_label.visible = new_health <= 0

func _on_dash_cooldown_changed(remaining: float, total: float):
	cooldown_bar.max_value = total
	cooldown_bar.value = total - remaining  # fills up as cooldown expires
	if remaining <= 0.0:
		cooldown_label.text = "READY"
	else:
		cooldown_label.text = str(snappedf(remaining, 0.1)) + "s"

func set_control_point_progress() -> void:
	var control_point_progress: Dictionary = get_parent().get_node("ControlPoint").progress
	var value: String
	if control_point_progress[0] >= 1:
		value = "Team A Wins!"
	elif control_point_progress[1] >= 1:
		value = "Team B Wins!"
	else:
		value = ("A: " + str(int(100*control_point_progress[0])) + "%  |  B: " + str(int(100*control_point_progress[1])) + "%")
	control_point_progress_label.text = value

func set_ping_label() -> void:
	ping_label.text = str(int(NetworkManager.get_peer_ping(NetworkManager.get_my_peer_id()))) + " ms"
 
func _on_hit_confirmed(shooter_id: int, _target_peer_id: int):
	if shooter_id == multiplayer.get_unique_id():
		on_hit()

func on_hit() -> void:
	var hit_marker_instance = load("res://ui/scenes/hit_marker.tscn").instantiate()
	add_child(hit_marker_instance)
