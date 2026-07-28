extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthContainer/HealthBar
@onready var health_label: Label = $HealthContainer/HealthLabel
@onready var ammo_label: Label = $AmmoContainer/AmmoLabel
@onready var reload_label: Label = $AmmoContainer/ReloadLabel
@onready var ability_container: HBoxContainer = $AbilityContainer
@onready var objective_label: Label = $ObjectiveContainer/ControlPointLabel
@onready var wins_label: Label = $ObjectiveContainer/WinsLabel
@onready var death_label: Label = $DeathLabel
@onready var respawn_timer_label: Label = $DeathLabel/RespawnTimer
@onready var ping_label: Label = $PingLabel
@onready var hit_marker_container: Control = $HitMarkerContainer
@onready var kill_feed_container: VBoxContainer = $KillFeedContainer

var local_player: HeroBase = null
var tracked_weapon: Weapon = null
var respawn_timer: float = 0.0
var is_dead: bool = false

const ABILITY_SLOT_DISPLAY = preload("res://ui/scenes/ability_slot_display.tscn")
const RESPAWN_DELAY: float = 5.0

func _ready():
	MatchEvents.hit_confirmed.connect(_on_hit_confirmed)
	MatchEvents.player_killed.connect(_on_player_killed)
	if not GameModeEvents.objective_progress_updated.is_connected(_on_objective_progress_updated):
		GameModeEvents.objective_progress_updated.connect(_on_objective_progress_updated)
	if not GameModeEvents.wins_updated.is_connected(_on_wins_updated):
		GameModeEvents.wins_updated.connect(_on_wins_updated)
	if not GameModeEvents.round_ended.is_connected(_on_round_ended):
		GameModeEvents.round_ended.connect(_on_round_ended)
	
	reload_label.hide()
	death_label.hide()
	hide()
	
	SceneManager.scene_loaded.connect(_on_scene_loaded)
	
	MatchEvents.player_killed.connect(_on_player_killed_check_local)

func _on_player_killed_check_local(killer_id: int, victim_id: int):
	_add_kill_feed_entry(killer_id, victim_id)
	if victim_id == multiplayer.get_unique_id():
		_on_local_player_died()

func _on_scene_loaded(scene: Node):
	if not scene.has_node("Players"):
		return
	
	await get_tree().process_frame
	
	var players_node = scene.get_node("Players")
	var my_id = str(multiplayer.get_unique_id())
	var player = players_node.get_node_or_null(my_id)
	
	if not player or not player is HeroBase:
		players_node.child_entered_tree.connect(_on_player_node_added)
		return
	
	local_player = player
	_connect_to_player(local_player)
	show()

func _on_player_node_added(node: Node):
	var my_id = str(multiplayer.get_unique_id())
	if node.name != my_id:
		return
	if not node is HeroBase:
		return
	
	var players_node = SceneManager.get_current_scene().get_node_or_null("Players")
	if players_node and players_node.child_entered_tree.is_connected(_on_player_node_added):
		players_node.child_entered_tree.disconnect(_on_player_node_added)
	
	await node.ready
	
	local_player = node
	_connect_to_player(local_player)
	show()

func _connect_to_player(player: HeroBase):
	player.health_component.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health_component.health)
	
	_connect_weapon(player.get_hud_weapon())
	
	_build_ability_displays(player.get_hud_abilities())

func _connect_weapon(weapon: Weapon):
	if not weapon:
		ammo_label.text = ""
		return
	if weapon == tracked_weapon:
		return
	
	if tracked_weapon:
		if tracked_weapon.ammo_changed.is_connected(_on_ammo_changed):
			tracked_weapon.ammo_changed.disconnect(_on_ammo_changed)
		if tracked_weapon.reload_started.is_connected(_on_reload_started):
			tracked_weapon.reload_started.disconnect(_on_reload_started)
		if tracked_weapon.reload_finished.is_connected(_on_reload_finished):
			tracked_weapon.reload_finished.disconnect(_on_reload_finished)
	
	tracked_weapon = weapon
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.reload_started.connect(_on_reload_started)
	weapon.reload_finished.connect(_on_reload_finished)
	_on_ammo_changed(weapon.current_ammo, weapon.data.max_ammo)

func _on_reload_started():
	reload_label.show()

func _on_reload_finished():
	reload_label.hide()

func _build_ability_displays(abilities: Array):
	for child in ability_container.get_children():
		child.queue_free()
	
	for ability in abilities:
		var display = ABILITY_SLOT_DISPLAY.instantiate()
		ability_container.add_child(display)
		display.connect_to_ability(ability)

func _process(delta: float):
	if not local_player:
		return
	
	set_ping_label()
	
	if local_player is HeroBase:
		var current_weapon = local_player.get_hud_weapon()
		if current_weapon != tracked_weapon:
			_connect_weapon(current_weapon)
	
	if is_dead:
		respawn_timer -= delta
		respawn_timer = maxf(respawn_timer, 0.0)
		respawn_timer_label.text = "Respawning in " + str(int(ceil(respawn_timer))) + "s"

func _on_health_changed(new_health: int):
	print("HUD health changed: ", new_health, " is_dead: ", is_dead)
	health_bar.value = new_health
	health_bar.max_value = local_player.health_component.MAX_HEALTH if local_player else 100
	health_label.text = str(new_health) + " HP"
	
	if new_health > 0 and is_dead:
		is_dead = false
		death_label.hide()

func _on_local_player_died():
	is_dead = true
	respawn_timer = RESPAWN_DELAY
	death_label.show()
	respawn_timer_label.text = "Respawning in " + str(int(RESPAWN_DELAY)) + "s"

func _on_ammo_changed(current: int, maximum: int):
	ammo_label.text = str(current) + " / " + str(maximum)

func _on_objective_progress_updated(data: Dictionary):
	var a = int(data.get(0, 0.0) * 100)
	var b = int(data.get(1, 0.0) * 100)
	
	var a_str = str(a) + "%"
	var b_str = str(b) + "%"
	
	objective_label.text = "A: " + a_str + "  |  B: " + b_str

func _on_wins_updated(team_wins: Dictionary):
	wins_label.text = "A: " + str(team_wins.get(0, 0)) + "  |  B: " + str(team_wins.get(1, 0))

func _on_round_ended(winning_team: int):
	var team_name = "Team A" if winning_team == 0 else "Team B"
	objective_label.text = team_name + " wins the round!"

func _on_hit_confirmed(shooter_id: int, _target_peer_id: int):
	if shooter_id == multiplayer.get_unique_id():
		on_hit()

func _on_player_killed(killer_id: int, victim_id: int):
	_add_kill_feed_entry(killer_id, victim_id)

func on_hit():
	var hit_marker = load("res://ui/scenes/hit_marker.tscn").instantiate()
	hit_marker_container.add_child(hit_marker)

func _add_kill_feed_entry(killer_id: int, victim_id: int):
	var label = Label.new()
	var killer_name = PlayerManager.get_player_name(killer_id)
	var victim_name = PlayerManager.get_player_name(victim_id)
	label.text = killer_name + " → " + victim_name
	kill_feed_container.add_child(label)
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(label):
		label.queue_free()

func set_ping_label():
	ping_label.text = str(int(NetworkManager.get_peer_ping(NetworkManager.get_my_peer_id()) * 1000)) + " ms"
