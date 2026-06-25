extends Resource
class_name WeaponData

enum WeaponSlot { PRIMARY, SECONDARY }

@export var weapon_name: String = ""
@export var icon: Texture2D
@export var slot: WeaponSlot = WeaponSlot.PRIMARY
@export var damage: int = 25
@export var max_ammo: int = 30
@export var fire_rate: float = 0.1
@export var reload_time: float = 1.5
@export var max_range: float = 100.0
@export var custom_stats: Dictionary = {}
