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
	name = "machinegun"
	desc = "a large machinegun."
	icon_state = ""
	item_state = ""
	layer = MOB_LAYER + 1
	anchored = TRUE
	density = TRUE
	w_class = 6
	load_method = SINGLE_CASING
	handle_casings = REMOVE_CASINGS
	max_shells = 6000
	caliber = "a762x54"
	slot_flags = FALSE
	ammo_type = /obj/item/ammo_casing/a762x54
	stat = "mg"

	firemodes = list(name="full auto",	burst=1, burst_delay=1.3, move_delay=8, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.5), accuracy=list(2))

	var/maximum_use_range = FALSE // user loc at minigun's current loc (used in use_object.dm)

	var/user_old_x = FALSE
	var/user_old_y = FALSE

	var/mob/last_user = null

	gun_type = GUN_TYPE_MG

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 1.1
	KD_chance = KD_CHANCE_MEDIUM

/obj/item/weapon/gun/projectile/automatic/stationary/attack_hand(var/mob/user)

	if (last_user && last_user != user)
		user << "<span class = 'warning'>\the [src] is already in use.</span>"
		return

	if (!(user.using_MG == src))
		var/grip_dir = reverse_direction(dir)
		var/turf/T = get_step(loc, grip_dir)
		if (user.loc == T)
			if (user.has_empty_hand(both = TRUE) && !is_used_by(user))
				if (!map || !map.check_caribbean_block(user, loc))
					if (do_after(user, 15, src))
						user.use_MG(src)
						usedby(user, src)
						started_using(user)
						if (user.loc != loc)
							user.use_MG(null)
			else
				user.show_message("<span class = 'warning'>You need both hands to use a machinegun.</span>")
		else
			user.show_message("<span class='warning'>You're too far from the handles.</span>")

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