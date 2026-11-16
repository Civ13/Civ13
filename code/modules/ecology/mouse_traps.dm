// Mouse traps (docs/mouse-nests.md).
//
// Like the stone-age trap line, mouse traps never wait for a mouse mob to walk
// in: every settle step each nest checks the traps within MOUSE_FORAGE_RANGE
// (the same look that finds its food) and each ready trap takes one mouse from
// the nest's population. A snap trap holds one mouse and is reset from the
// hand; a deadfall set indoors needs bait and is reset like any deadfall.

/obj/item/weapon/mousetrap
	name = "snap mousetrap"
	desc = "A wooden base with an iron spring bar and a bait pedal. Set it in your hand, then put it down where mice run."
	icon = 'icons/obj/mouse_nests.dmi'
	icon_state = "mousetrap_sprung"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 4
	var/armed = FALSE
	var/caught = FALSE

/obj/item/weapon/mousetrap/update_icon()
	if (caught)
		icon_state = "mousetrap_caught"
	else if (armed)
		icon_state = "mousetrap"
	else
		icon_state = "mousetrap_sprung"

/obj/item/weapon/mousetrap/examine(mob/user, distance = -1)
	..()
	if (caught)
		to_chat(user, SPAN_NOTICE("A dead mouse is pinned under the bar. Use it in your hand to empty it."))
	else if (armed)
		to_chat(user, SPAN_NOTICE("It is set."))
	else
		to_chat(user, "It is sprung. Use it in your hand to set it.")

/obj/item/weapon/mousetrap/attack_self(mob/user)
	if (caught)
		caught = FALSE
		armed = FALSE
		var/mob/living/simple_animal/mouse/M = new /mob/living/simple_animal/mouse(get_turf(user))
		M.death()
		to_chat(user, SPAN_NOTICE("You pull the dead mouse out of \the [src]."))
	else if (armed)
		armed = FALSE
		to_chat(user, SPAN_NOTICE("You carefully ease the bar of \the [src] down."))
	else
		armed = TRUE
		to_chat(user, SPAN_NOTICE("You pull back the bar and set \the [src]. Put it down where mice run."))
	update_icon()

// Ready to take a mouse: set, empty and lying on the floor.
/obj/item/weapon/mousetrap/proc/rodent_ready()
	return armed && !caught && isturf(loc)

/obj/item/weapon/mousetrap/proc/rodent_catch()
	armed = FALSE
	caught = TRUE
	update_icon()
	return TRUE

/obj/item/weapon/mousetrap/Crossed(atom/movable/AM)
	if (rodent_ready())
		if (istype(AM, /mob/living/simple_animal/mouse))
			var/mob/living/simple_animal/mouse/M = AM
			if (M.stat != DEAD)
				M.death()
				qdel(M)
				rodent_catch()
				playsound(src, 'sound/effects/snap.ogg', 30, TRUE)
		else if (ishuman(AM))
			var/mob/living/human/H = AM
			if (!H.lying && !H.shoes)
				H.apply_damage(2, BRUTE, pick("l_foot", "r_foot"), used_weapon = src)
			armed = FALSE
			update_icon()
			H.visible_message(SPAN_WARNING("\The [src] snaps under [H]'s foot!"), SPAN_WARNING("You step on \the [src] and it snaps shut!"))
	..()

// ---------------------------------------------------------------- indoor deadfall
/obj/structure/stone_age_trap/deadfall
	var/baited = FALSE

/obj/structure/stone_age_trap/deadfall/update_icon()
	if (armed && baited && !catch_type)
		icon = 'icons/obj/mouse_nests.dmi'
		icon_state = "deadfall_baited"
		return
	icon = initial(icon)
	..()

/obj/structure/stone_age_trap/deadfall/arm()
	baited = FALSE
	..()

// Indoors a deadfall only takes mice, through the nests near it.
/obj/structure/stone_age_trap/deadfall/catch_chance()
	var/area/A = get_area(src)
	if (A && A.location != AREA_OUTSIDE)
		return 0
	return ..()

/obj/structure/stone_age_trap/deadfall/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks) && !istype(W, /obj/item/weapon/reagent_containers/food/snacks/poo))
		if (!armed || catch_type)
			to_chat(user, SPAN_WARNING("Set \the [src] first."))
			return TRUE
		if (baited)
			to_chat(user, SPAN_NOTICE("\The [src] is already baited."))
			return TRUE
		baited = TRUE
		user.visible_message(SPAN_NOTICE("[user] baits \the [src] with \the [W]."), SPAN_NOTICE("You bait \the [src] with \the [W]. Mice nearby will go for it."))
		user.drop_from_inventory(W)
		qdel(W)
		update_icon()
		return TRUE
	return ..()

/obj/structure/stone_age_trap/deadfall/trap_status(mob/user)
	..()
	if (armed && !catch_type)
		to_chat(user, baited ? SPAN_NOTICE("It is baited for mice.") : "Bait it with a bit of food to catch mice.")

/obj/structure/stone_age_trap/deadfall/proc/rodent_ready()
	return armed && baited && !catch_type

/obj/structure/stone_age_trap/deadfall/proc/rodent_catch()
	armed = FALSE
	baited = FALSE
	catch_type = /mob/living/simple_animal/mouse
	caught_at = trap_minutes_text(trap_now_minutes())
	update_icon()
	return TRUE

// A deadfall can also be set on a floor indoors, where it catches only mice.
/obj/item/weapon/trap_kit/deadfall/target_ok(turf/T)
	if (trap_ground_ok(T))
		return TRUE
	if (!istype(T, /turf/floor) || T.density)
		return FALSE
	var/area/A = get_area(T)
	return A && A.location != AREA_OUTSIDE

/obj/item/weapon/trap_kit/deadfall/refuse_text()
	return "It has to be set on open ground outdoors (grass, dirt, sand or snow) or on a floor indoors."

// ---------------------------------------------------------------- nests use them
/proc/mouse_trap_ready(atom/movable/A)
	if (istype(A, /obj/item/weapon/mousetrap))
		var/obj/item/weapon/mousetrap/T = A
		return T.rodent_ready()
	if (istype(A, /obj/structure/stone_age_trap/deadfall))
		var/obj/structure/stone_age_trap/deadfall/D = A
		return D.rodent_ready()
	return FALSE

/proc/mouse_trap_catch(atom/movable/A)
	if (istype(A, /obj/item/weapon/mousetrap))
		var/obj/item/weapon/mousetrap/T = A
		return T.rodent_catch()
	if (istype(A, /obj/structure/stone_age_trap/deadfall))
		var/obj/structure/stone_age_trap/deadfall/D = A
		return D.rodent_catch()
	return FALSE

// Each ready trap near the nest takes one mouse. Returns how many were caught.
/obj/structure/mouse_nest/proc/spring_traps(list/traps)
	. = 0
	for (var/atom/movable/A in traps)
		if (population <= 0)
			break
		if (QDELETED(A) || !mouse_trap_ready(A))
			continue
		mouse_trap_catch(A)
		population--
		.++
