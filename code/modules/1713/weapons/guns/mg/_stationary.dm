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
	layer = MOB_LAYER + 3
	anchored = TRUE
	density = TRUE
	w_class = ITEM_SIZE_GARGANTUAN
	load_method = SINGLE_CASING
	handle_casings = REMOVE_CASINGS
	max_shells = 6000
	caliber = "a762x54"
	slot_flags = FALSE
	ammo_type = /obj/item/ammo_casing/a762x54
	stat = "machinegun"
	maxhealth = 6000
	firemodes = list(name = "full auto",	burst=1, burst_delay=1.3, move_delay=8, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.5), accuracy=list(2))
	full_auto = TRUE

	var/maximum_use_range = FALSE // user loc at minigun's current loc (used in use_object.dm)

	var/user_old_x = FALSE
	var/user_old_y = FALSE

	var/mob/last_user = null

	var/zoom_amount = 10
	is_hmg = TRUE

	var/hardness = 10

	gun_type = GUN_TYPE_MG

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 1.1
	KD_chance = KD_CHANCE_HIGH

/obj/item/weapon/gun/projectile/automatic/stationary/attack_hand(var/mob/user)

	if (last_user && last_user != user)
		user << "<span class = 'warning'>\the [src] is already in use.</span>"
		return

	if (!(user.using_MG == src))
		var/grip_dir = reverse_direction(dir)
		var/turf/T = get_step(loc, grip_dir)
		var/obj/structure/bed/chair/drivers/DR
		for (DR in src.loc.contents)
			if (DR in src.loc.contents)
				user << "<span class='notice'>There is a seat in the way.</span>"
				return
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
		if (src != /obj/item/weapon/gun/projectile/automatic/stationary/autocannon/atgm)
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

/obj/item/weapon/gun/projectile/automatic/stationary/proc/started_using(mob/living/human/user)
	..()

	user.forceMove(loc)
	user.dir = dir

	if (user.client)
		user.client.canmove = FALSE
		spawn (20)
			if (user && user.client)
				user.client.canmove = TRUE

	for (var/datum/action/A in actions)
		if (istype(A, /datum/action/toggle_scope))
			var/mob/living/human/H = user
			if (user.client.pixel_x | user.client.pixel_y)
				if (H.looking)
					H.look_into_distance(user, FALSE)
			var/datum/action/toggle_scope/S = A
			S.boundto = src//The lines including this line and the line below this call to two different files, could be helpful to combine the functions of the files
			H.look_into_distance(user, TRUE, TRUE)
			last_user = user
			break

/obj/item/weapon/gun/projectile/automatic/stationary/proc/stopped_using(mob/user as mob)
	..()

	for (var/datum/action/A in actions)
		if (istype(A, /datum/action/toggle_scope))
			var/mob/living/human/H = user
			var/datum/action/toggle_scope/TS = A
			if (TS.boundto == src)
				H.look_into_distance(user, FALSE)
				break

/obj/item/weapon/gun/projectile/automatic/stationary/proc/is_used_by(mob/user)
	return user.using_MG == src && user.loc == loc

/obj/item/weapon/gun/projectile/automatic/stationary/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (air_group || (height==0)) return TRUE
	if (istype(mover, /obj/item/projectile))
		return TRUE
	return FALSE

/obj/item/weapon/gun/projectile/automatic/stationary/rotate_to(mob/user, atom/A)
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

/mob/living/human/Move()
	handle_MG_operation()
	..()

/mob/living/human/update_canmove()
	if (lying || stat)
		handle_MG_operation(stop_using = TRUE)
	..()

/obj/item/weapon/gun/projectile/automatic/stationary/update_icon()
	if (ammo_magazine)
		icon_state = base_icon
	else
		icon_state = "[base_icon]_empty"
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/automatic/stationary/kick_act() //Can't kick them
	return