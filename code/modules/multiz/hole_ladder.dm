// A wooden ladder fitted into a player-dug hole. With a ladder in it the hole
// no longer swallows people who walk onto it, and both ends can be clicked to
// climb. Holes without a ladder keep their pit and trap behaviour.

/obj/item/weapon/hole_ladder
	name = "wooden ladder"
	desc = "A short wooden ladder. Use it on a dug hole to fit it, so people can climb in and out instead of falling."
	icon = 'icons/obj/stairs.dmi'
	icon_state = "siege_ladder"
	force = WEAPON_FORCE_WEAK
	w_class = ITEM_SIZE_LARGE
	attack_verb = list("bashed", "whacked")
	flammable = TRUE
	value = 2

/obj/structure/multiz/ladder/up/hole_ladder
	name = "wooden ladder"
	desc = "A wooden ladder leading up out of a dug hole."
	icon_state = "ladderup_wood"
	flammable = TRUE

/obj/structure/multiz/ladder/up/hole_ladder/New()
	..()
	ladder_list -= src // Never part of the mapped ladder numbering.

/obj/structure/multiz/ladder/up/hole_ladder/find_target()
	target = null
	return null

/obj/structure/multiz/ladder/up/hole_ladder/proc/hole_above()
	var/level = multiz_level_above(z)
	var/turf/T = level ? locate(x, y, level) : null
	if (!T)
		return null
	var/obj/structure/multiz/ladder/ww2/tunneltop/pit/P = locate() in T
	return P && P.has_ladder ? P : null

/obj/structure/multiz/ladder/up/hole_ladder/attack_hand(mob/user)
	if (!isliving(user) || !isturf(user.loc) || !Adjacent(user) || user.stat || user.restrained() || persistence_save_in_progress)
		return
	var/obj/structure/multiz/ladder/ww2/tunneltop/pit/P = hole_above()
	if (!P)
		to_chat(user, SPAN_WARNING("The ladder no longer leads anywhere."))
		return
	to_chat(user, SPAN_NOTICE("You start climbing up \the [src]."))
	if (!do_after(user, 10, src) || QDELETED(src) || QDELETED(P) || !P.has_ladder || !Adjacent(user) || user.stat || user.restrained() || user.buckled)
		return
	var/turf/T = get_turf(P)
	if (!persistence_movement_allowed(user, T))
		return
	if (user.pulling)
		user.stop_pulling()
	if (user.pulledby)
		user.pulledby.stop_pulling()
	if (trench_climb_place(user, T))
		playsound(T, 'sound/effects/ladder.ogg', 50, TRUE, -1)
		to_chat(user, SPAN_NOTICE("You climb out of the hole."))

/obj/structure/multiz/ladder/up/hole_ladder/attackby(obj/item/I, mob/user)
	return attack_hand(user)

/obj/structure/multiz/ladder/ww2/tunneltop/pit
	var/has_ladder = FALSE

/obj/structure/multiz/ladder/ww2/tunneltop/pit/get_saved_vars()
	. = ..()
	. |= list("has_ladder")

/obj/structure/multiz/ladder/ww2/tunneltop/pit/proc/lower_ladder()
	var/level = multiz_level_below(z)
	var/turf/T = level ? locate(x, y, level) : null
	return T ? locate(/obj/structure/multiz/ladder/up/hole_ladder) in T : null

/obj/structure/multiz/ladder/ww2/tunneltop/pit/Destroy()
	var/obj/structure/multiz/ladder/up/hole_ladder/L = lower_ladder()
	if (L)
		qdel(L)
	return ..()

/obj/structure/multiz/ladder/ww2/tunneltop/pit/update_icon()
	..()
	if (has_ladder && !leaf_covered)
		icon = 'icons/obj/stairs.dmi'
		icon_state = "ladderdown_wood"
		name = "dug hole with a ladder"

/obj/structure/multiz/ladder/ww2/tunneltop/pit/examine(mob/user, distance = -1)
	..(user, distance)
	if (has_ladder)
		to_chat(user, SPAN_NOTICE("A wooden ladder is fitted. Click to climb down; use grab intent to pull the ladder out."))
	else
		to_chat(user, SPAN_NOTICE("A wooden ladder would let people climb in and out safely."))

/obj/structure/multiz/ladder/ww2/tunneltop/pit/proc/fit_ladder(obj/item/weapon/hole_ladder/ladder, mob/user)
	if (has_ladder || leaf_covered)
		to_chat(user, SPAN_WARNING(has_ladder ? "There already is a ladder in this hole." : "Brush the leaves aside first."))
		return
	if (!Adjacent(user) || user.stat || user.restrained() || user.get_active_hand() != ladder || persistence_save_in_progress)
		return
	var/turf/T = landing()
	if (!T || (locate(/obj/structure/multiz) in T))
		to_chat(user, SPAN_WARNING("There is no clear floor at the bottom of this hole to stand the ladder on."))
		return
	to_chat(user, SPAN_NOTICE("You start lowering \the [ladder] into the hole."))
	if (!do_after(user, 30, src))
		return
	if (QDELETED(src) || QDELETED(ladder) || has_ladder || leaf_covered || !Adjacent(user) || user.stat || user.restrained() || user.get_active_hand() != ladder || persistence_save_in_progress)
		return
	T = landing()
	if (!T || (locate(/obj/structure/multiz) in T))
		return
	qdel(ladder)
	new /obj/structure/multiz/ladder/up/hole_ladder(T)
	has_ladder = TRUE
	update_icon()
	to_chat(user, SPAN_NOTICE("You fit the ladder. People can now climb in and out without falling."))

/obj/structure/multiz/ladder/ww2/tunneltop/pit/proc/remove_ladder(mob/user)
	if (!has_ladder || !Adjacent(user) || user.stat || user.restrained() || persistence_save_in_progress)
		return
	to_chat(user, SPAN_NOTICE("You start pulling the ladder out of the hole."))
	if (!do_after(user, 30, src) || QDELETED(src) || !has_ladder || !Adjacent(user) || user.stat || user.restrained() || persistence_save_in_progress)
		return
	var/obj/structure/multiz/ladder/up/hole_ladder/L = lower_ladder()
	if (L)
		qdel(L)
	has_ladder = FALSE
	update_icon()
	var/obj/item/weapon/hole_ladder/item = new(get_turf(user))
	user.put_in_hands(item)
	to_chat(user, SPAN_NOTICE("You pull the ladder out of the hole."))

/obj/structure/multiz/ladder/ww2/tunneltop/pit/attackby(obj/item/I, mob/user)
	if (istype(I, /obj/item/weapon/hole_ladder))
		fit_ladder(I, user)
		return
	if (istype(I, /obj/item/stack/material/leaf) && has_ladder)
		to_chat(user, SPAN_WARNING("The ladder sticks out of the hole. Pull it out before hiding the hole."))
		return
	return ..()

/obj/structure/multiz/ladder/ww2/tunneltop/pit/attack_hand(mob/user)
	if (!has_ladder || leaf_covered)
		return ..()
	if (!isliving(user) || !isturf(user.loc) || !Adjacent(user) || user.stat || user.restrained())
		return
	if (user.a_intent == I_GRAB)
		remove_ladder(user)
		return
	to_chat(user, SPAN_NOTICE("You start climbing down the ladder."))
	if (!do_after(user, 10, src) || QDELETED(src) || !has_ladder || !Adjacent(user) || user.stat || user.restrained() || user.buckled || persistence_save_in_progress)
		return
	var/turf/T = landing()
	if (!T || !persistence_movement_allowed(user, T))
		return
	if (user.pulling)
		user.stop_pulling()
	if (user.pulledby)
		user.pulledby.stop_pulling()
	if (trench_climb_place(user, T))
		playsound(T, 'sound/effects/ladder.ogg', 50, TRUE, -1)
		to_chat(user, SPAN_NOTICE("You climb down into the hole."))

// A fitted ladder gives a foothold: walking onto the hole no longer drops you in.
/obj/structure/multiz/ladder/ww2/tunneltop/pit/Crossed(atom/movable/A)
	if (has_ladder)
		return
	return ..()
