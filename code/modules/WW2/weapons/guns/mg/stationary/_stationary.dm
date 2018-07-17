//*********************
//POD MACHINEGUNS
//*********************

/obj/item/weapon/gun/projectile/automatic/stationary/verb/eject_mag()
	set category = null // was "Minigun" - removes lag
	set name = "Eject magazine"
	set src in range(1, usr)
	try_remove_mag(usr)

/////////////////////////////
////Stationary Machinegun////
/////////////////////////////
/obj/item/weapon/gun/projectile/automatic/stationary
	name = "minigun"
	desc = "6-barreled highspeed machinegun."
	icon_state = "minigun"
	item_state = ""
	layer = MOB_LAYER + 1
	anchored = TRUE
	density = TRUE
	w_class = 6
	load_method = SINGLE_CASING
	handle_casings = REMOVE_CASINGS
	max_shells = 6000
	caliber = "4mm"
	slot_flags = FALSE
	ammo_type = /obj/item/ammo_casing/c4mm
	stat = "MG"

	firemodes = list(
		list(name="3000 rpm", burst=10, burst_delay=0.1, fire_delay=0.4, dispersion=list(1.0)),
		list(name="6000 rpm", burst=20, burst_delay=0.05, fire_delay=0.2, dispersion=list(1.5))
		)

	var/maximum_use_range = FALSE // user loc at minigun's current loc (used in use_object.dm)

	var/user_old_x = FALSE
	var/user_old_y = FALSE

	var/mob/last_user = null

	gun_type = GUN_TYPE_MG

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 1.00
	KD_chance = KD_CHANCE_VERY_LOW
	stat = "MG"

/obj/item/weapon/gun/projectile/automatic/stationary/attack_hand(var/mob/user)

	if (last_user && last_user != user)
		user << "<span class = 'warning'>\the [src] is already in use.</span>"
		return

	if (user.using_MG == src)
		if (firemodes.len > 1)
			switch_firemodes(user)
	else
		var/grip_dir = reverse_direction(dir)
		var/turf/T = get_step(loc, grip_dir)
		if (user.loc == T)
			if (user.has_empty_hand(both = TRUE) && !is_used_by(user))
				if (!map || !map.check_prishtina_block(user, loc))
					if (do_after(user, 15, src))
						user.use_MG(src)
						usedby(user, src)
						started_using(user)
						if (user.loc != loc)
							user.use_MG(null)
			else
				user.show_message("<span class = 'warning'>You need both hands to use a minigun.</span>")
		else
			user.show_message("<span class='warning'>You're too far from the handles.</span>")
/*
/obj/item/weapon/gun/projectile/automatic/stationary/proc/try_use_sights(mob/user)
	if (is_used_by(user))
		//toggle_scope(2.0)
	else
		user.visible_message("<span class='warning'>You aren't using \the [src].</span>")*/

// An ugly hack called a boolean proc, made it like this to allow special
// behaviour without too many overrides. So special snowflake weapons like the minigun
// can use zoom without overriding the original zoom proc.
//	user: user mob
//	devicename: name of what device you are peering through, set by zoom() in items.dm
//	silent: boolean controlling whether it should tell the user why they can't zoom in or not
// I am sorry for creating this abomination -- Irra
///obj/item/weapon/gun/projectile/automatic/stationary/can_zoom(mob/user, var/devicename, var/silent)
	//if (user.stat || !ishuman(user))
		//if (!silent) user.show_message("You are unable to focus through the [devicename]")
		//return FALSE
	//else if (!zoomed && global_hud.darkMask[1] in user.client.screen)
		//if (!silent) user.show_message("Your visor gets in the way of looking through the [devicename]")
		//return FALSE
	return TRUE

/obj/item/weapon/gun/projectile/automatic/stationary/proc/try_remove_mag(mob/user)
	if (!ishuman(user))
		return
	if (!is_used_by(user))
		if (user.has_empty_hand())
			unload_ammo(user)
		else
			user.show_message("<span class='warning'>You need an empty hand for this.</span>")
	else
		user.show_message("<span class='warning'>You can't do this while using \the [src].</span>")

/obj/item/weapon/gun/projectile/automatic/stationary/proc/usedby(mob/user, atom/A, params)
	if (A == src)
		switch_firemodes(user)

	if (check_direction(user, A))
		afterattack(A, user, FALSE, params)
	else
	//	rotate_to(user, A)
		update_layer()

/obj/item/weapon/gun/projectile/automatic/stationary/proc/check_direction(mob/user, atom/A)
	if (get_turf(A) == loc)
		return FALSE

	var/shot_dir = get_carginal_dir(src, A)

	if (shot_dir != dir)
		return FALSE

	return TRUE

/obj/item/weapon/gun/projectile/automatic/stationary/proc/rotate_to(mob/user, atom/A)
	user.show_message("<span class='warning'>You can't turn the [name] there.</span>")
	return FALSE

/obj/item/weapon/gun/projectile/automatic/stationary/proc/update_layer()
	if (dir == NORTH)
		layer = OBJ_LAYER+0.1 // above any casings we drop but below mobs
	else
		layer = FLY_LAYER

/obj/item/weapon/gun/projectile/automatic/stationary/proc/started_using(mob/living/carbon/human/user)
	..()

	user.forceMove(loc)
	user.dir = dir

	if (user.client)
		user.client.canmove = FALSE
		spawn (20)
			user.client.canmove = TRUE

	for (var/datum/action/A in actions)
		if (istype(A, /datum/action/toggle_scope))
			if (user.client.pixel_x | user.client.pixel_y)
				for (var/datum/action/toggle_scope/T in user.actions)
					if (T.scope.zoomed)
						T.scope.zoom(user, FALSE)
			var/datum/action/toggle_scope/S = A
			S.boundto = src
			S.scope.zoom(user, TRUE, TRUE)
			last_user = user
			break

/obj/item/weapon/gun/projectile/automatic/stationary/proc/stopped_using(mob/user as mob)
	..()

	for (var/datum/action/A in actions)
		if (istype(A, /datum/action/toggle_scope))
			var/datum/action/toggle_scope/TS = A
			if (TS.boundto == src)
				var/datum/action/toggle_scope/S = A
				S.scope.zoom(user, FALSE)
				break

/obj/item/weapon/gun/projectile/automatic/stationary/proc/is_used_by(mob/user)
	return user.using_MG == src && user.loc == loc

/obj/item/weapon/gun/projectile/automatic/stationary/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (air_group || (height==0)) return TRUE
	if (istype(mover, /obj/item/projectile))
		return TRUE
	return FALSE

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
	magazine_type = /obj/item/ammo_magazine/a127x108
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
