extends Player
class_name HeroBase

# Slot dictionaries — populated automatically from Abilities node children
var ability_slots: Dictionary = {}  # AbilityData.AbilitySlot: Ability
var weapon_slots: Dictionary = {}   # WeaponData.WeaponSlot: Weapon

# For heroes with form swaps (like Captain)
# Set active_abilities_node to switch which Abilities node is registered
var active_abilities_node: Node = null

signal damage_dealt(amount: int)
signal healing_done(amount: int)

func _ready():
	super._ready()
	
	# Find the first Abilities node and register it
	var abilities_node = get_node_or_null("Abilities")
	if abilities_node:
		_register_from_node(abilities_node)
		active_abilities_node = abilities_node

func _register_from_node(node: Node):
	ability_slots.clear()
	weapon_slots.clear()
	print("registering abilites (hero_base.gd)")
	for child in node.get_children():
		if child is Ability:
			child.setup(self)
			if child.data:
				print("ability has data")
				ability_slots[child.data.slot] = child
		elif child is Weapon:
			child.setup(self)
			if child.data:
				weapon_slots[child.data.slot] = child

func swap_abilities(new_abilities_node: Node):
	# Disable current
	if active_abilities_node:
		active_abilities_node.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Enable and register new
	active_abilities_node = new_abilities_node
	active_abilities_node.process_mode = Node.PROCESS_MODE_INHERIT
	_register_from_node(active_abilities_node)

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SENSITIVITY)
		head.rotate_x(-event.relative.y * SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	
	if event.is_action_pressed("primary_fire"):
		_handle_primary_fire()
	
	if event.is_action_pressed("ability1"):
		var ability = ability_slots.get(AbilityData.AbilitySlot.ABILITY_1)
		if ability:
			ability.try_activate()
	
	if event.is_action_pressed("ability2"):
		var ability = ability_slots.get(AbilityData.AbilitySlot.ABILITY_2)
		if ability:
			ability.try_activate()
	
	if event.is_action_pressed("ultimate"):
		var ability = ability_slots.get(AbilityData.AbilitySlot.ULTIMATE)
		if ability:
			ability.try_activate()
	
	if event.is_action_pressed("reload"):
		_handle_reload()

func _handle_primary_fire():
	# Default behaviour — fire primary weapon
	var weapon = weapon_slots.get(WeaponData.WeaponSlot.PRIMARY)
	if weapon:
		weapon.try_fire()

func _handle_reload():
	var weapon = weapon_slots.get(WeaponData.WeaponSlot.PRIMARY)
	if weapon:
		weapon.reload()

func get_ability(slot: AbilityData.AbilitySlot) -> Ability:
	return ability_slots.get(slot)

func get_weapon(slot: WeaponData.WeaponSlot) -> Weapon:
	return weapon_slots.get(slot)
