extends Player
class_name HeroBase

@export var max_health: int = 100
@export var move_speed: float = 10.0

func _ready():
	super._ready()
	# Apply stats
	health_component.MAX_HEALTH = max_health
	health_component.health = max_health
	SPEED = move_speed
	
