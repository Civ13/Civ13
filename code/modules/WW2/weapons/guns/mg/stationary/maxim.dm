/obj/item/weapon/gun/projectile/automatic/stationary/kord/maxim
	name = "Movable Maxim M1910"
	desc = "Heavy Maxim machinegun on cart mount. You can see 'Batya Makhno' scribed on it's water cooler."
	icon_state = "maxim"
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	caliber = "a762x54"
	magazine_type = /obj/item/ammo_magazine/maxim
	max_shells = FALSE
	anchored = FALSE
	auto_eject = TRUE
	fire_sound = 'sound/weapons/maxim_shot.ogg'
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


/obj/item/weapon/gun/projectile/automatic/stationary/maximstat
	name = "Stationary Maxim M1910"
	desc = "Maxim machinegun established on special wooden pod."
	icon_state = "maximstat"
	item_state = "maximstat"
	layer = FLY_LAYER
	anchored = TRUE
	density = TRUE
	w_class = 6
	magazine_type = /obj/item/ammo_magazine/maxim
	auto_eject = TRUE
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	max_shells = FALSE
	caliber = "a762x54"
	fire_sound = 'sound/weapons/maxim_shot.ogg'
	slot_flags = FALSE
	ammo_type = /obj/item/ammo_casing/a762x54

	firemodes = list(	// changed burst from 3 to 6, burst_delay from 2.5 to 0.1 to make this more mg-ish - Kachnov
		list(name="default", burst=10, burst_delay=0.1, fire_delay=0.75, dispersion=list(0.9, 1.1, 1.1, 1.1, 1.3), accuracy=list(2))
		)


/obj/item/weapon/gun/projectile/automatic/stationary/maximstat/update_icon()
	if (ammo_magazine)
		icon_state = "maximstat"
/*		if (wielded)
			item_state = "maximstat"
		else
			item_state = "maximstat"*/
	else
		icon_state = "maximstat0"
/*		if (wielded)
			item_state = "maximstat0"
		else
			item_state = "maxomstat0"*/
	update_held_icon()
	return
