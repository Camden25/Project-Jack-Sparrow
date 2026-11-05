extends Ability
class_name UltimateAbility

@export var ultimate_cost: float = 1000.0

var current_charge: float = 0.0

signal charge_changed(current: float, cost: float)

func setup(player: HeroBase):
	super.setup(player)
	set_multiplayer_authority(1)
	if not owner_player.damage_dealt.is_connected(_on_damage_dealt):
		owner_player.damage_dealt.connect(_on_damage_dealt)
	if not owner_player.healing_done.is_connected(_on_healing_done):
		owner_player.healing_done.connect(_on_healing_done)

func _on_damage_dealt(amount: int):
	if not multiplayer.is_server() or is_ready():
		return
	_set_charge(current_charge + float(amount))

func _on_healing_done(amount: int):
	if not multiplayer.is_server() or is_ready():
		return
	_set_charge(current_charge + float(amount))

func _set_charge(charge: float):
	current_charge = clampf(charge, 0.0, ultimate_cost)
	emit_signal("charge_changed", current_charge, ultimate_cost)

	var owner_peer_id = owner_player.get_multiplayer_authority()
	if owner_peer_id != 1:
		_sync_charge.rpc_id(owner_peer_id, current_charge)

@rpc("authority", "call_remote", "reliable")
func _sync_charge(charge: float):
	current_charge = clampf(charge, 0.0, ultimate_cost)
	emit_signal("charge_changed", current_charge, ultimate_cost)

func is_ready() -> bool:
	return current_charge >= ultimate_cost

func _can_activate() -> bool:
	return super._can_activate() and is_ready()

func _activate():
	pass  # override in subclass

func _use_ultimate():
	if not multiplayer.is_server():
		return
	_set_charge(0.0)
