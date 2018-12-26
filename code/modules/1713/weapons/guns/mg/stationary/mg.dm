
///////////////////////
////Stationary KORD////
///////////////////////
/obj/item/weapon/gun/projectile/automatic/stationary/kord
	name = "KORD"
	desc = "Heavy machinegun"
	icon_state = "kord"
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	caliber = "a127x108"
	magazine_type = /obj/item/ammo_magazine/projectile/maxim
	max_shells = FALSE

	fire_sound = 'sound/weapons/WW2/kord1.ogg'

	firemodes = list(
		list(name="default", burst=3, burst_delay=0.5, fire_delay=1.5, dispersion=list(0), accuracy=list(2))
		)

/obj/item/weapon/gun/projectile/automatic/stationary/kord/rotate_to(mob/user, atom/A)
	var/shot_dir = get_carginal_dir(src, A)
	dir = shot_dir

	//if (zoomed)
		//zoom(user, FALSE) //Stop Zoom

	user.forceMove(loc)
	user.dir = dir

// helpers

/mob/var/using_MG = null
/mob/proc/use_MG(o)
	if (!o || !istype(o, /obj/item/weapon/gun/projectile/automatic/stationary))
		using_MG = null
	else
		using_MG = o

/mob/proc/handle_MG_operation(var/stop_using = FALSE)
	if (using_MG && istype(using_MG, /obj/item/weapon/gun/projectile/automatic/stationary))
		var/obj/item/weapon/gun/projectile/automatic/stationary/mg = using_MG
		if (!(locate(src) in range(mg.maximum_use_range, mg)) || stop_using)
			use_MG(null)
			mg.stopped_using(src)
	else if (!locate(using_MG) in range(1, src) || stop_using)
		use_MG(null)

/mob/Move()
	. = ..()
	handle_MG_operation()

/mob/update_canmove()
	. = ..()
	if (lying || stat)
		handle_MG_operation(stop_using = TRUE)



/obj/item/weapon/gun/projectile/automatic/stationary/type92stat
	name = "Stationary Type 92"
	desc = "Type 92 machinegun established on special pod."
	icon_state = "Type92HMG"
	item_state = "Type92HMG"
	layer = FLY_LAYER
	anchored = TRUE
	density = TRUE
	w_class = 6
	magazine_type = /obj/item/ammo_magazine/projectile/maxim/type92_belt
	auto_eject = TRUE
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	max_shells = FALSE
	caliber = "a77x58"
	fire_sound = 'sound/weapons/mg34_firing.ogg'
	slot_flags = FALSE
	ammo_type = /obj/item/projectile/bullet/rifle/a762x38

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
		icon_state = "Type92HMG_empty"
/*		if (wielded)
			item_state = "mg34stat0"
		else
			item_state = "mg34stat0"*/
	update_held_icon()
	return

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
	icon = 'icons/obj/maxim.dmi'
	name = "Stationary Maxim 1895"
	desc = "A Maxim machine gun use by armies around the globe."
	icon_state = "maxim_stat"
	item_state = "maxim_stat"
	layer = FLY_LAYER
	anchored = TRUE
	density = TRUE
	w_class = 6
	magazine_type = /obj/item/ammo_magazine/maxim
	auto_eject = TRUE
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	max_shells = FALSE
	caliber = "a792x54"
	fire_sound = 'sound/weapons/maxim_shot.ogg'
	slot_flags = FALSE
	ammo_type = /obj/item/ammo_casing/a792x54
	gun_type = GUN_TYPE_MG
	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 1.00
	KD_chance = KD_CHANCE_VERY_LOW
	firemodes = list(	// changed burst from 3 to 6, burst_delay from 2.5 to 0.1 to make this more mg-ish - Kachnov
		list(name="default", burst=10, burst_delay=0.1, fire_delay=0.75, dispersion=list(0.9, 1.1, 1.1, 1.1, 1.3), accuracy=list(2))
		)


/obj/item/weapon/gun/projectile/automatic/stationary/maximstat/update_icon()
	if (ammo_magazine)
		icon_state = "maxim_stat"
/*		if (wielded)
			item_state = "maximstat"
		else
			item_state = "maximstat"*/
	else
		icon_state = "maxim_stat0"
/*		if (wielded)
			item_state = "maximstat0"
		else
			item_state = "maxomstat0"*/
	update_held_icon()
	return
