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

/obj/structure/attack_hand(mob/M, icon_x, icon_y)
	if (climbers.len && !(M in climbers))
		M.visible_message("<span class='warning'>[M] shakes \the [src].</span>", \
					"<span class='notice'>You shake \the [src].</span>")
		structure_shaken()

	return ..()

/obj/structure/attackby(obj/item/O as obj, mob/user as mob, icon_x, icon_y)
	if (istype(O,/obj/item/weapon/wrench) && !not_movable)
		if (powersource)
			to_chat(user, SPAN_NOTICE("Remove the cables first."))
			return
		if (istype(src, /obj/structure/engine))
			var/obj/structure/engine/EN = src
			if (!isemptylist(EN.connections))
				to_chat(user, SPAN_NOTICE("Remove the cables first."))
				return
		if (do_after(user,15,src))
			playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
			to_chat(user, (anchored ? SPAN_NOTICE("You unfasten \the [src] from the floor.") : SPAN_NOTICE("You secure \the [src] to the floor.")))
			anchored = !anchored
			return
	else if (istype(O,/obj/item/weapon/hammer) && !not_disassemblable)
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		to_chat(user, SPAN_NOTICE("You begin dismantling \the [src]."))
		if (do_after(user,25,src))
			to_chat(user, SPAN_NOTICE("You dismantle \the [src]."))
			new /obj/item/stack/material/wood(get_turf(src))
			for (var/obj/item/weapon/book/b in contents)
				b.loc = (get_turf(src))
			qdel(src)
			return


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
		to_chat(user, SPAN_WARNING("You cannot pass the invisible wall until the <b>Grace Period</b> has ended."))
		return FALSE

	if (!climbable || !can_touch(user) || (!post_climb_check && (user in climbers)))
		return FALSE

	if (!user.Adjacent(src) && !istype(src, /obj/structure/window/barrier))
		to_chat(user, SPAN_DANGER("You can't climb there, the way is blocked."))
		return FALSE

	var/obj/occupied = turf_is_crowded(user)

	if (occupied)
		to_chat(user, SPAN_DANGER("There's \a [occupied] in the way."))
		return FALSE
	return TRUE
	
/obj/structure/proc/turf_is_crowded(var/mob/living/user)
    var/turf/T = get_step(get_turf(user), src.dir) // Target-Turf
    var/turf/TT = get_turf(src) // Start-Turf

    // Check for climbable objects in the target turf
    for (var/obj/O in T.contents)
        if (istype(O, /obj/structure))
            var/obj/structure/S = O
            if (!S) continue  // Skip if S is not valid
            if (S.climbable) continue  // Skip if the object is climbable	
            if (O && O.density && !(O.flags & ON_BORDER)) //ON_BORDER structures are handled by the Adjacent() check.
                return O // Return the dense object that blocks our way.

    // Check for climbable objects in the start turf
    for (var/obj/O in TT.contents)
        if (istype(O, /obj/structure))
            var/obj/structure/S = O
            if (!S) continue  // Skip if S is not valid
            if (S.climbable) continue  // Skip if the object is climbable
            if (O && O.density && !(O.flags & ON_BORDER)) //ON_BORDER structures are handled by the Adjacent() check.
                return O //  Return the dense object that blocks our way.
    
    // If no crowded object is found, return FALSE
    return FALSE

/obj/structure/proc/neighbor_turf_passable()
    var/turf/T = get_step(src, dir)
    if (!T || !istype(T))
        return FALSE
    if (T.density == TRUE)
        return FALSE
    for (var/obj/O in T.contents)  // Iterate over all objects in the turf
        // Check if the object has density
        if (istype(O, /obj/structure/closet/crate))
            continue // Allow us to climb onto crates
        if (istype(O, /obj/structure/table))
            continue // Allow us to climb onto other tables
        if (O.density == TRUE)
            return FALSE
    return TRUE


/obj/structure/proc/do_climb(var/mob/living/user)
	if (!can_climb(user))
		return
	if (map.check_caribbean_block(user, get_turf(src)))
		return

	var/turf/T = get_turf(src) // Target-Turf
	if (src.flags & ON_BORDER)
		T = get_step(get_turf(src), dir)
		if (user.loc == T)
			T = get_turf(src)

	var/turf/U = get_turf(user) // Start-Turf
	if (!istype(T) || !istype(U))
		return FALSE

	// Check if the target turf is a table or a crate
	if (istype(src, /obj/structure/closet/crate) || istype(src, /obj/structure/barricade)) // we check for barricades because [sand]stone walls are under this.
		if (user.loc == src.loc)
			to_chat(user, SPAN_WARNING("You're already on this!"))
			return
		if(climbable) // necessary to check if the siege-ladder has changed the climbable value for [sand]stone walls (barricades), good check regardless.
			if (!T || T.density)
				return
			user.visible_message(SPAN_WARNING("[user] starts climbing onto \the [src]!"), SPAN_WARNING("You start climbing onto \the [src]!"))
			user.face_atom(T)
			climbers |= user
			if (!do_after(user,(issmall(user) ? 20 : 34)))
				climbers -= user
				return
			if (!can_climb(user, post_climb_check=1))
				climbers -= user
				return
			user.forceMove(T)
			if (get_turf(user) == T)
				user.visible_message(SPAN_WARNING("[user] climbs onto \the [src]!"), SPAN_WARNING("You climb onto \the [src]!"))
				if (istype(src, /obj/structure/table/glass))
					var/obj/structure/table/glass/G = src
					G.shatter()
			climbers -= user
			return

	var/climb_dir = src.dir  // Direction of the barrier that the user is trying to climb
	var/opposite_dir = reverse_direction(climb_dir)  // Reverse the direction to simulate a barrier in the opposite direction facing towards us.

	// Check if the user is not directly in front of or behind the barrier
	var/turf/next_turf = get_step(T, climb_dir)  
	if (user.loc != next_turf)  
		next_turf = get_step(T, opposite_dir)  
		if (user.loc != next_turf)  
			to_chat(user, SPAN_WARNING("You can't vault this barrier. You must be directly next to it."))
			return

	// Check if there's a barrier with opposite direction facing the climbing direction
	for (var/obj/I in T)
		if (I.dir == opposite_dir && istype(I, /obj/structure/window/barrier))
			to_chat(user, SPAN_WARNING("You can't vault this barrier. \A [I.name] is blocking the way."))
			return

	if (!neighbor_turf_passable())
		to_chat(user, SPAN_DANGER("You can't climb there, the way is blocked."))
		climbers -= user
		return

	user.visible_message(SPAN_WARNING("[user] starts climbing onto \the [src]!"), SPAN_WARNING("You start climbing onto \the [src]!"))
	user.face_atom(T)
	climbers |= user

	if (!do_after(user,(issmall(user) ? 20 : 34)))
		climbers -= user
		climb_dir = null  // Reset climb_dir to null
		opposite_dir = null  // Reset opposite_dir to null
		return

	if (!can_climb(user, post_climb_check=1))
		climb_dir = null  // Reset climb_dir to null
		opposite_dir = null  // Reset opposite_dir to null
		climbers -= user
		return

	user.forceMove(T)

	if (get_turf(user) == T)
		user.visible_message(SPAN_WARNING("[user] climbs onto \the [src]!"), SPAN_WARNING("You climb onto \the [src]!"))
		if (istype(src, /obj/structure/table/glass))
			var/obj/structure/table/glass/G = src
			G.shatter()
	climbers -= user
	climb_dir = null  // Reset climb_dir to null
	opposite_dir = null  // Reset opposite_dir to null

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
		to_chat(user, SPAN_NOTICE("You need your hands and legs free for this."))
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

/obj/structure/proc/connect_cable(var/mob/user, var/obj/item/stack/cable_coil/W)
	if (powersource)
		to_chat(user, "There's already a cable connected here! Split it further from \the [src]")
		return
	var/obj/item/stack/cable_coil/CC = W
	powersource = CC.place_turf(get_turf(src), user, turn(get_dir(user,src),180))
	if (!powersource)
		return
	powersource.connections += src
	var/opdir1 = 0
	var/opdir2 = 0
	if (powersource.tiledir == "horizontal")
		opdir1 = 4
		opdir2 = 8
	else if  (powersource.tiledir == "vertical")
		opdir1 = 1
		opdir2 = 2
	powersource.update_icon()

	if (opdir1 != 0 && opdir2 != 0)
		for(var/obj/structure/cable/NCOO in get_turf(get_step(powersource,opdir1)))
			if ((NCOO.tiledir == powersource.tiledir) && NCOO != powersource)
				if (!(powersource in NCOO.connections) && !list_cmp(powersource.connections, NCOO.connections))
					NCOO.connections += powersource
				if (!(NCOO in powersource.connections) && !list_cmp(powersource.connections, NCOO.connections))
					powersource.connections += NCOO
				to_chat(user, "You connect the two cables.")

		for(var/obj/structure/cable/NCOC in get_turf(get_step(powersource,opdir2)))
			if ((NCOC.tiledir == powersource.tiledir) && NCOC != powersource)
				if (!(powersource in NCOC.connections) && !list_cmp(powersource.connections, NCOC.connections))
					NCOC.connections += powersource
				if (!(NCOC in powersource.connections) && !list_cmp(powersource.connections, NCOC.connections))
					powersource.connections += NCOC
	to_chat(user, SPAN_NOTICE("You connect the cable to \the [src]."))
