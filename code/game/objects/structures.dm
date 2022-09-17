/obj/structure
	icon = 'icons/obj/structures.dmi'
	w_class = 10

	var/climbable = FALSE
	var/breakable = FALSE
	var/parts
	var/list/climbers = list()
	var/low = FALSE


	var/not_movable = TRUE
	var/not_disassemblable = TRUE
/obj/structure/Destroy()
	if (parts)
		new parts(loc)
	..()

/obj/structure/attack_hand(mob/user, icon_x, icon_y)
	if (climbers.len && !(user in climbers))
		user.visible_message("<span class='warning'>[user.name] shakes \the [src].</span>", \
					"<span class='notice'>You shake \the [src].</span>")
		structure_shaken()

	return ..()

/obj/structure/attackby(obj/item/O as obj, mob/user as mob, icon_x, icon_y)
	if (istype(O,/obj/item/weapon/wrench) && !not_movable)
		if (powersource)
			user << "<span class='notice'>Remove the cables first.</span>"
			return
		if (istype(src, /obj/structure/engine))
			var/obj/structure/engine/EN = src
			if (!isemptylist(EN.connections))
				user << "<span class='notice'>Remove the cables first.</span>"
				return
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
		return
	else if (istype(O,/obj/item/weapon/hammer) && !not_disassemblable)
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		user << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You dismantle \the [src].</span>"
			new /obj/item/stack/material/wood(get_turf(src))
			for (var/obj/item/weapon/book/b in contents)
				b.loc = (get_turf(src))
			qdel(src)
			return
	else
		..()


/obj/structure/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE
	else if (istype(mover, /obj/item/projectile))
		if (prob(66) && density)
			return TRUE
		else
			visible_message("<span class = 'warning'>The [mover.name] riochetes off \the [src]!</span>")
			return FALSE
	else
		return ..()
/*
/obj/structure/attack_tk()
	return
*/
/obj/structure/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(50))
				qdel(src)
				return
		if (3.0)
			return

/obj/structure/MouseDrop_T(mob/target, mob/user)

	var/mob/living/H = user
	if (istype(H) && can_climb(H) && target == user)
		user.dir = get_dir(user, src)
		do_climb(target)
	else
		return ..()

/obj/structure/proc/can_climb(var/mob/living/user, post_climb_check=0)

	var/movingto = get_step(get_turf(src), dir)
	if (map && movingto && map.check_caribbean_block(user, movingto))
		user << "<span class = 'warning'>You cannot pass the invisible wall until the Grace Period has ended.</span>"
		return FALSE

	if (!climbable || !can_touch(user) || (!post_climb_check && (user in climbers)))
		return FALSE

	if (!user.Adjacent(src) && !istype(src, /obj/structure/window/barrier))
		user << "<span class='danger'>You can't climb there, the way is blocked.</span>"
		return FALSE

	var/obj/occupied = turf_is_crowded()
	if (occupied)
		user << "<span class='danger'>There's \a [occupied] in the way.</span>"
		return FALSE
	return TRUE

/obj/structure/proc/turf_is_crowded()
	var/turf/T = get_turf(src)
	if (!T || !istype(T))
		return FALSE
	for (var/obj/O in T.contents)
		if (istype(O,/obj/structure))
			var/obj/structure/S = O
			if (S.climbable) continue
		if (O && O.density && !(O.flags & ON_BORDER)) //ON_BORDER structures are handled by the Adjacent() check.
			return O
	return FALSE

/obj/structure/proc/neighbor_turf_passable()
	var/turf/T = get_step(src, dir)
	if (!T || !istype(T))
		return FALSE
	if (T.density == TRUE)
		return FALSE
	for (var/obj/O in T.contents)
		if (istype(O,/obj/structure))
			if (istype(O,/obj/structure/railing))
				return TRUE
			else if (O.density == TRUE)
				return FALSE
	return TRUE

/obj/structure/proc/do_climb(var/mob/living/user)
	if (!can_climb(user))
		return

	user.face_atom(src)

	var/turf/target = null

	if (istype(src, /obj/structure/window/barrier))
		target = get_step(user, user.dir)
	else
		target = get_turf(src)

	if (!target || target.density || (map && map.check_caribbean_block(user, target)))
		return

	for (var/obj/structure/S in target)
		if (S != src && S.density)
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
		if (S != src && S.density)
			return

	usr.forceMove(target)

	if (get_turf(user) == target)
		usr.visible_message("<span class='warning'>[user] climbs onto \the [src]!</span>")
		if (istype(src, /obj/structure/table/glass))
			var/obj/structure/table/glass/G = src
			G.shatter()
	climbers -= user

/obj/structure/proc/structure_shaken()
	for (var/mob/living/M in climbers)
		M.Weaken(1)
		M << "<span class='danger'>You topple as you are shaken off \the [src]!</span>"
		climbers.Cut(1,2)

	for (var/mob/living/M in get_turf(src))
		if (M.lying) return //No spamming this on people.

		M.Weaken(3)
		M << "<span class='danger'>You topple as \the [src] moves under you!</span>"

		if (prob(25))

			var/damage = rand(15,30)
			var/mob/living/human/H = M
			if (!istype(H))
				H << "<span class='danger'>You land heavily!</span>"
				M.adjustBruteLoss(damage)
				return

			var/obj/item/organ/external/affecting

			switch(pick(list("ankle","wrist","head","knee","elbow")))
				if ("ankle")
					affecting = H.get_organ(pick("l_foot", "r_foot"))
				if ("knee")
					affecting = H.get_organ(pick("l_leg", "r_leg"))
				if ("wrist")
					affecting = H.get_organ(pick("l_hand", "r_hand"))
				if ("elbow")
					affecting = H.get_organ(pick("l_arm", "r_arm"))
				if ("head")
					affecting = H.get_organ("head")

			if (affecting)
				M << "<span class='danger'>You land heavily on your [affecting.name]!</span>"
				affecting.take_damage(damage, FALSE)
			else
				H << "<span class='danger'>You land heavily!</span>"
				H.adjustBruteLoss(damage)

			H.UpdateDamageIcon()
			H.updatehealth()
	return

/obj/structure/proc/can_touch(var/mob/user)
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

/obj/structure/attack_generic(var/mob/user, var/damage, var/attack_verb, var/wallbreaker)
	if (!breakable || !damage || !wallbreaker)
		return FALSE
	visible_message("<span class='danger'>[user] [attack_verb] the [src] apart!</span>")
	attack_animation(user)
	spawn(1) qdel(src)
	return TRUE
