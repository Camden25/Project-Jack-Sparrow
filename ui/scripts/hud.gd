extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthContainer/HealthBar
@onready var health_label: Label = $HealthContainer/HealthLabel
@onready var ammo_label: Label = $AmmoContainer/AmmoLabel
@onready var cooldown_bar: ProgressBar = $AbilityCooldown/CooldownBar
@onready var cooldown_label: Label = $AbilityCooldown/CooldownLabel

var local_player: Player = null

func _ready():
	# Wait for world to spawn local player
	NetworkManager.player_connected.connect(_on_player_connected)
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

func _on_health_changed(new_health: int):
	health_bar.value = new_health
	health_bar.max_value = 100
	health_label.text = str(new_health) + " HP"

func _on_dash_cooldown_changed(remaining: float, total: float):
	cooldown_bar.max_value = total
	cooldown_bar.value = total - remaining  # fills up as cooldown expires
	if remaining <= 0.0:
		cooldown_label.text = "READY"
	else:
		cooldown_label.text = str(snappedf(remaining, 0.1)) + "s"
