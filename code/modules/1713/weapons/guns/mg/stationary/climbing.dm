// snowflake code - Kachnov
/obj/item/weapon/gun/projectile/automatic/stationary/var/climbers = list()

/obj/item/weapon/gun/projectile/automatic/stationary/verb/rotate_left()
	set name = "Rotate Left"
	set category = null
	set src in oview(1)

	if (!istype(usr, /mob/living))
		return

	set_dir(turn(dir, -90))
	return

/obj/item/weapon/gun/projectile/automatic/stationary/verb/rotate_right()
	set name = "Rotate Right"
	set category = null
	set src in oview(1)

	if (!istype(usr, /mob/living))
		return

	set_dir(turn(dir, 90))
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

	usr.visible_message("<span class='warning'>[user] starts climbing onto \the [src]!</span>")
	climbers |= user

	if (!do_after(user,(issmall(user) ? 20 : 34)))
		climbers -= user
		return

	if (!can_climb(user, post_climb_check=1))
		climbers -= user
		return

	if (!target || target.density)
		return

	for (var/obj/structure/S in target)
		if (S.density)
			return

	usr.loc = target.loc

	if (get_turf(user) == get_turf(src))
		usr.visible_message("<span class='warning'>[user] climbs onto \the [src]!</span>")
	climbers -= user

/obj/item/weapon/gun/projectile/automatic/stationary/proc/can_touch(var/mob/user)
	if (!user)
		return FALSE
	if (!Adjacent(user))
		return FALSE
	if (user.restrained() || user.buckled)
		user << "<span class='notice'>You need your hands and legs free for this.</span>"
		return FALSE
	if (user.stat || user.paralysis || user.sleeping || user.lying || user.weakened)
		return FALSE
	return TRUE