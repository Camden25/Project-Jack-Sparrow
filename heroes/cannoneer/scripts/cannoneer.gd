extends HeroBase
class_name Cannoneer

func _ready():
	super._ready()

func _handle_primary_fire():
	var crew_shot := get_ability(AbilityData.AbilitySlot.ABILITY_2)
	if crew_shot and crew_shot.handle_primary_fire():
		return
	super._handle_primary_fire()
