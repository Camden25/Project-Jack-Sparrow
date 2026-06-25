extends Ability
class_name UltimateAbility

@export var ultimate_cost: float = 1000.0

var current_charge: float = 0.0

signal charge_changed(current: float, cost: float)

func setup(player: HeroBase):
	super.setup(player)
	# Hook into hero signals for charge
	owner_player.damage_dealt.connect(_on_damage_dealt)
	owner_player.healing_done.connect(_on_healing_done)

func _on_damage_dealt(amount: int):
	if is_ready():
		return
	current_charge += float(amount)
	current_charge = minf(current_charge, ultimate_cost)
	emit_signal("charge_changed", current_charge, ultimate_cost)

func _on_healing_done(amount: int):
	if is_ready():
		return
	current_charge += float(amount)
	current_charge = minf(current_charge, ultimate_cost)
	emit_signal("charge_changed", current_charge, ultimate_cost)

func is_ready() -> bool:
	return current_charge >= ultimate_cost

func _can_activate() -> bool:
	return is_ready()

func _activate():
	pass  # override in subclass

func _use_ultimate():
	# Call this at the end of _activate() in subclasses
	current_charge = 0.0
	emit_signal("charge_changed", current_charge, ultimate_cost)
