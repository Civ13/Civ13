/obj/item/weapon/gun/projectile/automatic/stationary/kord/mg34
	name = "Movable MG34"
	desc = "German light machinegun chambered in 7.92x57mm Mauser. An utterly devastating support weapon. This one is movable."
	icon_state = "mg34movable"
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	caliber = "a792x57"
	magazine_type = /obj/item/ammo_magazine/maxim/mg34_belt
	unload_sound 	= 'sound/weapons/guns/interact/lmg_magout.ogg'
	reload_sound 	= 'sound/weapons/guns/interact/lmg_magin.ogg'
	cocked_sound 	= 'sound/weapons/guns/interact/lmg_cock.ogg'
	fire_sound = 'sound/weapons/guns/fire/mg34_firing.ogg'
	max_shells = FALSE
	anchored = FALSE
	auto_eject = TRUE
	firemodes = list(
		list(name="default", burst=6, burst_delay=0.6, fire_delay=1.0, dispersion=list(0.9, 1.1, 1.1, 1.1, 1.3), accuracy=list(2))
		)
	fire_delay = 3

/obj/item/weapon/gun/projectile/automatic/stationary/kord/mg34/update_icon()
	if (ammo_magazine)
		icon_state = "mg34movable"
/*		if (wielded)
			item_state = "mg34movable"
		else
			item_state = "mg34movable"*/
	else
		icon_state = "mg34movable0"
/*		if (wielded)
			item_state = "mg34movable0"
		else
			item_state = "mg34movable0"*/
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/automatic/stationary/mg34stat
	name = "Stationary MG34"
	desc = "MG34 machinegun established on special wooden pod."
	icon_state = "mg34stat"
	item_state = "mg34stat"
	layer = FLY_LAYER
	anchored = TRUE
	density = TRUE
	w_class = 6
	magazine_type = /obj/item/ammo_magazine/maxim/mg34_belt
	auto_eject = TRUE
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	max_shells = FALSE
	caliber = "a792x57"
	fire_sound = 'sound/weapons/guns/fire/mg34_firing.ogg'
	slot_flags = FALSE
	ammo_type = /obj/item/ammo_casing/a792x57_weaker

	firemodes = list(	// changed burst from 3 to 6, burst_delay from 2.5 to 0.1 to make this more mg-ish - Kachnov
		list(name="default", burst=10, burst_delay=0.1, fire_delay=0.75, dispersion=list(0.9, 1.1, 1.1, 1.1, 1.3), accuracy=list(2))
		)

/obj/item/weapon/gun/projectile/automatic/stationary/mg34stat/update_icon()
	if (ammo_magazine)
		icon_state = "mg34stat"
/*		if (wielded)
			item_state = "mg34stat"
		else
			item_state = "mg34stat"*/
	else
		icon_state = "mg34stat0"
/*		if (wielded)
			item_state = "mg34stat0"
		else
			item_state = "mg34stat0"*/
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/automatic/stationary/type92stat
	name = "Stationary Type 92"
	desc = "Type 92 machinegun established on special pod."
	icon_state = "Type92HMG"
	item_state = "Type92HMG"
	layer = FLY_LAYER
	anchored = TRUE
	density = TRUE
	w_class = 6
	magazine_type = /obj/item/ammo_magazine/maxim/type92_belt
	auto_eject = TRUE
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	max_shells = FALSE
	caliber = "a77x58"
	fire_sound = 'sound/weapons/guns/fire/mg34_firing.ogg'
	slot_flags = FALSE
	ammo_type = /obj/item/ammo_casing/a77x58_weaker

	firemodes = list(	// changed burst from 3 to 6, burst_delay from 2.5 to 0.1 to make this more mg-ish - Kachnov
		list(name="default", burst=10, burst_delay=0.1, fire_delay=0.75, dispersion=list(0.9, 1.1, 1.1, 1.1, 1.3), accuracy=list(2))
		)

/obj/item/weapon/gun/projectile/automatic/stationary/type92stat/update_icon()
	if (ammo_magazine)
		icon_state = "Type92HMG"
/*		if (wielded)
			item_state = "mg34stat"
		else
			item_state = "mg34stat"*/
	else
		icon_state = "Type92HMG0"
/*		if (wielded)
			item_state = "mg34stat0"
		else
			item_state = "mg34stat0"*/
	update_held_icon()
	return
