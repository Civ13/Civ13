/obj/item/weapon/gun/projectile/automatic/stationary
	name = "Maxim 1895"
	desc = "Heavy Maxim machinegun on cart mount."
	icon_state = "maxim"
	base_icon = "maxim"
	stat = "machinegun"
	maxhealth = 500
	layer = MOB_LAYER + 3

	max_shells = 500
	w_class = ITEM_SIZE_GARGANTUAN
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS

	density = TRUE
	anchored = FALSE
	auto_eject = TRUE

	caliber = "a762x54"
	magazine_type = /obj/item/ammo_magazine/maxim
	ammo_type = /obj/item/ammo_casing/a762x54

	fire_sound = 'sound/weapons/guns/fire/Maxim.ogg'
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=2, fire_delay=2, accuracy=list(2))
		)
	slot_flags = FALSE
	full_auto = TRUE
	fire_delay = 0
	recoil = 10 // Stationary weapons have virtually no recoil
	accuracy = 3

	var/climbers = list()
	var/can_turn = TRUE // Used for fixed coaxial MGs (like the Breda 30)
	var/hardness = 10 // How easy bullets can penetrate it

	var/maximum_use_range = 0 // user loc at minigun's current loc (used in use_object.dm)
	var/user_old_x = 0
	var/user_old_y = 0

	var/mob/used_by_mob = null

	var/zoom_amount = 10
	is_hmg = TRUE

	gun_type = GUN_TYPE_MG

	accuracy_increase_mod = 1.00
	accuracy_decrease_mod = 1.1
	KD_chance = KD_CHANCE_HIGH

/obj/item/weapon/gun/projectile/automatic/stationary/Destroy()
	if(used_by_mob)
		stopped_using(used_by_mob, FALSE)
	..()

/obj/item/weapon/gun/projectile/automatic/stationary/Fire(atom/A, mob/user)
	if(A == src)
		if(firemodes.len > 1)
			var/datum/firemode/new_mode = switch_firemodes(user)
			if(new_mode)
				to_chat(user, SPAN_NOTICE("\The [src] is now set to [new_mode.name]."))
				return
	if(check_direction(user, A))
		return ..()
	else
		rotate_to(user, A)
		update_pixels(user)
		update_layer()
		return

/obj/item/weapon/gun/projectile/automatic/stationary/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (air_group || !density) return TRUE
	if (istype(mover, /obj/item/projectile))
		return TRUE
	return FALSE

/obj/item/weapon/gun/projectile/automatic/stationary/MouseDrop(over_object, src_location, over_location)
	..()
	if((over_object == usr && in_range(src, usr)) && !used_by_mob)
		unload_ammo(usr, 0)
		return

/obj/item/weapon/gun/projectile/automatic/stationary/attack_hand(mob/user)
	if (used_by_mob && used_by_mob != user)
		to_chat(user, SPAN_WARNING("\The [src] is already in use."))
		return

	var/grip_dir = reverse_direction(dir)
	var/turf/T = get_step(src.loc, grip_dir)
	var/turf/TT = get_turf(src)

	for (var/obj/structure/bed/chair/drivers/DR in TT.contents)
		if (DR in TT.contents)
			to_chat(user, SPAN_NOTICE("There is a seat in the way."))
			return

	if (user.loc == src.loc)
		if (user.has_empty_hand(both = TRUE))
			if (!map || !map.check_caribbean_block(user, loc))
				if (do_after(user, 5, src))
					started_using(user)
					return
		else
			to_chat(user, SPAN_WARNING("You need both hands to use \the [src]."))
			return
	if (user.loc == T || istype(src, /obj/item/weapon/gun/projectile/automatic/stationary/autocannon))
		if (user.has_empty_hand(both = TRUE))
			if (!map || !map.check_caribbean_block(user, loc))
				if (do_after(user, 15, src))
					started_using(user)
					return
		else
			to_chat(user, SPAN_WARNING("You need both hands to use \the [src]."))
			return

	else
		to_chat(user, SPAN_WARNING("You're too far from the handles."))
		return

/obj/item/weapon/gun/projectile/automatic/stationary/proc/update_layer()
	if(dir == NORTH)
		layer = OBJ_LAYER + 0.1
	else
		layer = FLY_LAYER

/obj/item/weapon/gun/projectile/automatic/stationary/proc/check_direction(mob/user, atom/A)
	if (user.buckled)
		return TRUE

	if (get_turf(A) == loc)
		return FALSE

	var/shot_dir = get_carginal_dir(src, A)
	if (shot_dir != dir)
		return FALSE

	return TRUE

/obj/item/weapon/gun/projectile/automatic/stationary/proc/rotate_to(mob/user, atom/A)
	/*
	var/shot_dir = get_carginal_dir(src, A)
	dir = shot_dir

	if (zoomed)
		zoom(user, FALSE) //Stop Zoom

	user.forceMove(loc)
	user.dir = dir
	*/
	return

/obj/item/weapon/gun/projectile/automatic/stationary/proc/update_pixels(mob/user as mob)
	if(user.buckled)
		return
	var/diff_x = 0
	var/diff_y = 0
	if(dir == EAST)
		diff_x = -16 + user_old_x
	if(dir == WEST)
		diff_x = 16 + user_old_x
	if(dir == NORTH)
		diff_y = -16 + user_old_y
	if(dir == SOUTH)
		diff_y = 16 + user_old_y
	animate(user, pixel_x=diff_x, pixel_y=diff_y, 4, 1)

/obj/item/weapon/gun/projectile/automatic/stationary/proc/started_using(mob/user as mob, var/need_message = TRUE)
	if(user.buckled)
		return
	if(need_message)
		user.visible_message(SPAN_NOTICE("[user.name] handles \the [src]."), SPAN_NOTICE("You handle \the [src]."))
	used_by_mob = user
	user.using_object = src
	user.update_canmove()
	user.forceMove(src.loc)
	user.set_dir(src.dir)
	user_old_x = user.pixel_x
	user_old_y = user.pixel_y
	update_pixels(user)
	update_layer()

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
			S.boundto = src //The lines including this line and the line below this call to two different files, could be helpful to combine the functions of the files
			H.look_into_distance(user, TRUE, TRUE)
			used_by_mob = user
			break

/obj/item/weapon/gun/projectile/automatic/stationary/proc/stopped_using(mob/user as mob, var/need_message = TRUE)
	if(need_message)
		user.visible_message(SPAN_NOTICE("[user.name] releases \the [src]."), SPAN_NOTICE("You release \the [src]."))
	used_by_mob = null
	user.using_object = null
	user.update_canmove()
	animate(user, pixel_x=user_old_x, pixel_y=user_old_y, 4, 1)
	user_old_x = 0
	user_old_y = 0

	for (var/datum/action/A in actions)
		if (istype(A, /datum/action/toggle_scope))
			var/mob/living/human/H = user
			var/datum/action/toggle_scope/TS = A
			if (TS.boundto == src)
				H.look_into_distance(user, FALSE)
				break

/obj/item/weapon/gun/projectile/automatic/stationary/verb/rotate_left()
	set name = "Rotate Left"
	set category = null
	set src in oview(1)

	if (!istype(usr, /mob/living))
		return
	if (usr == used_by_mob)
		to_chat(usr, SPAN_WARNING("You cannot turn \the [src] while on it."))
	if (can_turn)
		set_dir(turn(dir, 90))
	else
		to_chat(usr, SPAN_WARNING("\The [src] is incapable of turning."))
	return

/obj/item/weapon/gun/projectile/automatic/stationary/verb/rotate_right()
	set name = "Rotate Right"
	set category = null
	set src in oview(1)

	if (!istype(usr, /mob/living))
		return
	if (usr == used_by_mob)
		to_chat(usr, SPAN_WARNING("You cannot turn \the [src] while on it."))
	if (can_turn)
		set_dir(turn(dir, -90))
	else
		to_chat(usr, SPAN_WARNING("\The [src] is incapable of turning."))
	return

/obj/item/weapon/gun/projectile/automatic/stationary/MouseDrop_T(mob/target, mob/user)
	return

/obj/item/weapon/gun/projectile/automatic/stationary/proc/can_climb(var/mob/living/user, post_climb_check=0)
	return FALSE

/obj/item/weapon/gun/projectile/automatic/stationary/proc/turf_is_crowded()
	var/turf/T = get_turf(src)
	if (!T || !istype(T))
		return FALSE
	for (var/obj/O in T.contents)
		if (O == src)
			continue
		if (istype(O,/obj/structure) && !istype(O, /obj/structure/vehicleparts))
			var/obj/structure/S = O
			if (S.climbable) continue
		if (O && O.density && !(O.flags & ON_BORDER) && !istype(O, /obj/structure/vehicleparts)) //ON_BORDER structures are handled by the Adjacent() check.
			return O
	return FALSE

/obj/item/weapon/gun/projectile/automatic/stationary/proc/do_climb(var/mob/living/user)
	if (!can_climb(user))
		return

	user.face_atom(src)

	var/turf/target = null

	if (istype(src, /obj/structure/window/barrier))
		target = get_step(src, user.dir)
	else
		target = get_turf(src)

	if (!target || target.density)
		return

	for (var/obj/structure/S in target)
		if (S.density)
			return

	usr.visible_message(SPAN_WARNING("[user] starts climbing onto \the [src]!"))
	climbers |= user

	if (!do_after(user,(issmall(user) ? 20 : 34)))
		climbers -= user
		return

	if (!can_climb(user, post_climb_check = TRUE))
		climbers -= user
		return

	if (!target || target.density)
		return

	for (var/obj/structure/S in target)
		if (S.density)
			return

	usr.loc = target.loc

	if (get_turf(user) == get_turf(src))
		usr.visible_message(SPAN_WARNING("[user] climbs onto \the [src]!"))
	climbers -= user

/obj/item/weapon/gun/projectile/automatic/stationary/proc/can_touch(var/mob/user)
	if (!user)
		return FALSE
	if (!Adjacent(user))
		return FALSE
	if (user.restrained() || user.buckled)
		to_chat(user, SPAN_NOTICE("You need your hands and legs free for this."))
		return FALSE
	if (user.stat || user.paralysis || user.sleeping || user.lying || user.weakened)
		return FALSE
	return TRUE

// helpers

/mob/living/human/Move()
	if(using_object && istype(using_object, /obj/item/weapon/gun/projectile/automatic/stationary))
		var/obj/item/weapon/gun/projectile/automatic/stationary/HMG = using_object
		HMG.stopped_using(src)
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