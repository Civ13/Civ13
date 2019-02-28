/obj/item/weapon/gun/projectile/automatic/stationary/maxim/maxim
	name = "Maxim 1895"
	desc = "Heavy Maxim machinegun on cart mount."
	icon_state = "maxim"
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	caliber = "a762x54"
	magazine_type = /obj/item/ammo_magazine/maxim
	max_shells = FALSE
	anchored = FALSE
	auto_eject = TRUE
	fire_sound = 'sound/weapons/WW2/kord1.ogg'
	firemodes = list(
		list(name="default", burst=6, burst_delay=0.6, fire_delay=1.0, dispersion=list(0.9, 1.1, 1.1, 1.1, 1.3), accuracy=list(2))
		)

/obj/item/weapon/gun/projectile/automatic/stationary/kord/maxim/update_icon()
	if (ammo_magazine)
		icon_state = "maxim"
/*		if (wielded)
			item_state = "maxim"
		else
			item_state = "maxim"*/
	else
		icon_state = "maxim0"
/*		if (wielded)
			item_state = "maxim0"
		else
			item_state = "maxom0"*/
	update_held_icon()
	return