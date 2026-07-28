extends Resource
class_name AbilityData

enum AbilitySlot { PRIMARY, SECONDARY, ABILITY_1, ABILITY_2, ABILITY_3, ULTIMATE }

@export var ability_name: String = ""
@export var icon: Texture2D
@export var slot: AbilitySlot = AbilitySlot.ABILITY_1
@export var cooldown: float = 0.0
@export var max_uses: int = -1  # -1 = unlimited
@export var custom_stats: Dictionary = {}
