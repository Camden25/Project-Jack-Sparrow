extends HeroBase
class_name ExNavyOfficer

func _ready():
	super._ready()

func _handle_primary_fire():
	var musket: Musket = get_weapon(WeaponData.WeaponSlot.PRIMARY)
	var flintlock: Flintlock = get_weapon(WeaponData.WeaponSlot.SECONDARY)
	
	if musket and musket.is_aiming:
		musket.try_fire()
	elif flintlock:
		flintlock.try_fire()

func _handle_reload():
	var musket: Musket = get_weapon(WeaponData.WeaponSlot.PRIMARY)
	if musket and musket.is_aiming:
		musket.reload()
	else:
		var flintlock: Flintlock = get_weapon(WeaponData.WeaponSlot.SECONDARY)
		if flintlock:
			flintlock.reload()
