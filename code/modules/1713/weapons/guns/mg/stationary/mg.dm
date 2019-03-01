
///////////////////////
////Stationary maxim////
///////////////////////
/obj/item/weapon/gun/projectile/automatic/stationary/maxim
	name = "Maxim 1895"
	desc = "Heavy Maxim machinegun on cart mount."
	icon_state = "maxim"
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	caliber = "a762x54"
	magazine_type = /obj/item/ammo_magazine/maxim
	ammo_type = /obj/item/ammo_casing/a762x54

	max_shells = FALSE
	anchored = FALSE
	auto_eject = TRUE
	fire_sound = 'sound/weapons/WW2/kord1.ogg'
	firemodes = list(
		list(name="full auto", burst=6, burst_delay=0.6, fire_delay=1.0, dispersion=list(0.8, 0.9, 1.1, 1.2, 1.3), accuracy=list(2))
		)
/obj/item/weapon/gun/projectile/automatic/stationary/maxim/rotate_to(mob/user, atom/A)
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


/obj/item/weapon/gun/projectile/automatic/stationary/maxim/update_icon()
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