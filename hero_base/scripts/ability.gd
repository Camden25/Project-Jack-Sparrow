extends Node
class_name Ability

@export var data: AbilityData

var owner_player: HeroBase = null
var cooldown_timer: float = 0.0
var uses_remaining: int = -1
var is_on_cooldown: bool = false

signal cooldown_changed(remaining: float, total: float)
signal uses_changed(remaining: int, maximum: int)

func setup(player: HeroBase):
	owner_player = player
	if data and data.max_uses != -1:
		uses_remaining = data.max_uses

func try_activate():
	if not _can_activate():
		return
	_activate()
	if data:
		if data.max_uses != -1:
			print("multi use not implemented yet")
			#uses_remaining -= 1
			#emit_signal("uses_changed", uses_remaining, data.max_uses)
		if data.cooldown > 0:
			_start_cooldown()

func _can_activate() -> bool:
	if is_on_cooldown:
		return false
	if data and data.max_uses != -1 and uses_remaining <= 0:
		return false
	return true

func _activate():
	pass  # override in subclass

func _start_cooldown():
	is_on_cooldown = true
	cooldown_timer = data.cooldown
	emit_signal("cooldown_changed", cooldown_timer, data.cooldown)

func reduce_cooldown(amount: float):
	if not is_on_cooldown:
		return
	cooldown_timer = max(0.0, cooldown_timer - amount)
	if cooldown_timer <= 0.0:
		is_on_cooldown = false
	emit_signal("cooldown_changed", cooldown_timer, data.cooldown)

func reset_cooldown():
	cooldown_timer = 0.0
	is_on_cooldown = false
	if data:
		emit_signal("cooldown_changed", 0.0, data.cooldown)

func _process(delta: float):
	if not is_on_cooldown:
		return
	cooldown_timer -= delta
	cooldown_timer = max(0.0, cooldown_timer)
	if data:
		emit_signal("cooldown_changed", cooldown_timer, data.cooldown)
	if cooldown_timer <= 0.0:
		is_on_cooldown = false

func physics_update(delta: float):
	pass
