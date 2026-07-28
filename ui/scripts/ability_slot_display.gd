extends Control

@onready var icon_rect: TextureRect = $Background/IconRect
@onready var cooldown_overlay: Control = $Background/CooldownOverlay
@onready var overlay_rect: ColorRect = $Background/CooldownOverlay/OverlayRect
@onready var cooldown_label: Label = $Background/CooldownLabel
@onready var charge_bar: ProgressBar = $Background/ChargeBar
@onready var keybind_label: Label = $Background/KeybindLabel

var connected_ability: Ability = null

func connect_to_ability(ability: Ability):
	connected_ability = ability
	
	# Set icon if data has one
	if ability.data and ability.data.icon:
		icon_rect.texture = ability.data.icon
	
	# Set keybind label based on slot
	if ability.data:
		keybind_label.text = _get_keybind_label(ability.data.slot)
	
	if ability is UltimateAbility:
		charge_bar.show()
		cooldown_overlay.hide()
		cooldown_label.hide()
		charge_bar.max_value = ability.ultimate_cost
		charge_bar.value = ability.current_charge
		ability.charge_changed.connect(_on_charge_changed)
	else:
		charge_bar.hide()
		cooldown_overlay.show()
		overlay_rect.color = Color(0, 0, 0, 0.6)
		if ability.data:
			_on_cooldown_changed(0.0, ability.data.cooldown)
		ability.cooldown_changed.connect(_on_cooldown_changed)

func _on_cooldown_changed(remaining: float, total: float):
	if total <= 0.0:
		_set_ready()
		return
	
	var ratio = remaining / total
	
	overlay_rect.anchor_top = 1-ratio
	
	if remaining <= 0.0:
		_set_ready()
	else:
		cooldown_label.text = str(snappedf(remaining, 0.1)) + "s"
		cooldown_overlay.show()

func _on_charge_changed(current: float, cost: float):
	charge_bar.value = current
	if current >= cost:
		cooldown_label.text = "READY"
		cooldown_label.modulate = Color.YELLOW
	else:
		cooldown_label.text = str(int((current / cost) * 100)) + "%"
		cooldown_label.modulate = Color.WHITE

func _set_ready():
	cooldown_overlay.hide()
	cooldown_label.text = "READY"

func _get_keybind_label(slot: AbilityData.AbilitySlot) -> String:
	match slot:
		AbilityData.AbilitySlot.PRIMARY:
			return "LMB"
		AbilityData.AbilitySlot.SECONDARY:
			return "RMB"
		AbilityData.AbilitySlot.ABILITY_1:
			return "Shift"
		AbilityData.AbilitySlot.ABILITY_2:
			return "E"
		AbilityData.AbilitySlot.ULTIMATE:
			return "Q"
		_:
			return ""
