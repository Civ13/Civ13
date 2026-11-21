// A wooden ladder fitted into a player-dug hole. With a ladder in it the hole
// no longer swallows people who walk onto it, and both ends can be clicked to
// climb. Holes without a ladder keep their pit and trap behaviour.

/obj/item/weapon/hole_ladder
	name = "wooden ladder"
	desc = "A short wooden ladder. Use it on a dug hole to fit it, on open air beside an upper floor, or on the ground under open air, so people can climb between levels instead of falling."
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

// A dug opening is an object over an otherwise solid-looking upper turf.
// Resolve the reciprocal column, not a client-selected upper atom.
/proc/dug_pit_above_ladder_site(turf/lower)
	if (!lower)
		return null
	var/level = multiz_level_above(lower.z)
	var/turf/upper = level ? locate(lower.x, lower.y, level) : null
	if (!upper || multiz_level_below(upper.z) != lower.z)
		return null
	return locate(/obj/structure/multiz/ladder/ww2/tunneltop/pit) in upper

/obj/structure/multiz/ladder/ww2/tunneltop/pit/proc/dug_open_to_below(turf/lower)
	var/turf/upper = loc
	if (QDELETED(src) || !isturf(upper) || dug_pit_above_ladder_site(lower) != src || leaf_covered || upper.density || trapdoor_shut_at(upper))
		return FALSE
	if (locate(/obj/roof) in lower)
		return FALSE
	for (var/atom/movable/A in upper)
		if (A != src && !QDELETED(A) && !isliving(A) && (A.density || istype(A, /obj/covers)))
			return FALSE
	return TRUE

/obj/structure/multiz/ladder/ww2/tunneltop/pit/proc/below_ladder_worksite(mob/user, turf/lower)
	if (!user || !lower || !isturf(user.loc) || user.z != lower.z || !lower.Adjacent(user) || persistence_active_operation || persistence_load_recovery_required || !dug_open_to_below(lower))
		return FALSE
	return !istype(get_area(src), /area/caribbean/no_mans_land) && !istype(get_area(lower), /area/caribbean/no_mans_land)

/obj/structure/multiz/ladder/up/hole_ladder/proc/hole_above()
	var/obj/structure/multiz/ladder/ww2/tunneltop/pit/P = dug_pit_above_ladder_site(get_turf(src))
	return P && P.has_ladder ? P : null

/obj/structure/multiz/ladder/up/hole_ladder/attack_hand(mob/user)
	if (!isliving(user) || !isturf(user.loc) || !Adjacent(user) || user.stat || user.restrained() || persistence_save_in_progress)
		return
	if (trapdoor_from_below(get_turf(src), user))
		return
	var/obj/structure/multiz/ladder/ww2/tunneltop/pit/P = hole_above()
	if (!P)
		to_chat(user, SPAN_WARNING("The ladder no longer leads anywhere."))
		return
	if (user.a_intent == I_GRAB && !user.get_active_hand())
		P.remove_ladder(user, src)
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

/obj/structure/multiz/ladder/up/hole_ladder/examine(mob/user, distance = -1)
	..()
	to_chat(user, SPAN_NOTICE("Click to climb up, or use Grab with an empty hand to take down the ladder."))

/obj/structure/multiz/ladder/up/hole_ladder/attackby(obj/item/I, mob/user)
	if (trapdoor_from_below(get_turf(src), user, I))
		return
	return attack_hand(user)

/obj/structure/multiz/ladder/ww2/tunneltop/pit
	var/has_ladder = FALSE

/obj/structure/multiz/ladder/ww2/tunneltop/pit/get_saved_vars()
	. = ..()
	. |= list("has_ladder")

// A fitted ladder comes back out when the hole is filled in.
/obj/structure/multiz/ladder/ww2/tunneltop/pit/tunnel_filled(mob/user)
	if (!has_ladder)
		return
	has_ladder = FALSE
	new /obj/item/weapon/hole_ladder(user ? get_turf(user) : get_turf(src))
	to_chat(user, SPAN_NOTICE("You pull the ladder out before the earth buries it."))

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

/obj/structure/multiz/ladder/ww2/tunneltop/pit/proc/fit_ladder(obj/item/weapon/hole_ladder/ladder, mob/user, turf/from_below = null)
	if (has_ladder || leaf_covered)
		to_chat(user, SPAN_WARNING(has_ladder ? "There already is a ladder in this hole." : "Brush the leaves aside first."))
		return
	if (from_below && !below_ladder_worksite(user, from_below))
		to_chat(user, SPAN_WARNING("You can't reach the open shaft from here."))
		return
	if ((!from_below && !Adjacent(user)) || user.stat || user.restrained() || user.get_active_hand() != ladder || persistence_save_in_progress)
		return
	var/turf/T = landing()
	if (!T || (from_below && T != from_below) || (locate(/obj/structure/multiz) in T))
		to_chat(user, SPAN_WARNING("There is no clear floor at the bottom of this hole to stand the ladder on."))
		return
	to_chat(user, SPAN_NOTICE("[from_below ? "You start standing" : "You start lowering"] \the [ladder] into the hole."))
	var/atom/worksite = from_below ? from_below : src
	if (!do_after(user, 30, worksite))
		return
	if (QDELETED(src) || QDELETED(ladder) || has_ladder || leaf_covered || (from_below ? !below_ladder_worksite(user, from_below) : !Adjacent(user)) || user.stat || user.restrained() || user.get_active_hand() != ladder || persistence_save_in_progress)
		return
	T = landing()
	if (!T || (from_below && T != from_below) || (locate(/obj/structure/multiz) in T))
		return
	qdel(ladder)
	new /obj/structure/multiz/ladder/up/hole_ladder(T)
	has_ladder = TRUE
	update_icon()
	to_chat(user, SPAN_NOTICE("You fit the ladder. People can now climb in and out without falling."))

/obj/structure/multiz/ladder/ww2/tunneltop/pit/proc/remove_ladder(mob/user, obj/structure/multiz/ladder/up/hole_ladder/from_below = null)
	if (!has_ladder || user.stat || user.restrained() || persistence_save_in_progress)
		return
	var/turf/lower = from_below ? get_turf(from_below) : null
	if (from_below ? (!below_ladder_worksite(user, lower) || landing() != lower || lower_ladder() != from_below || user.get_active_hand()) : !Adjacent(user))
		return
	to_chat(user, SPAN_NOTICE("You start pulling the ladder out of the hole."))
	var/atom/worksite = from_below ? from_below : src
	if (!do_after(user, 30, worksite) || QDELETED(src) || !has_ladder || user.stat || user.restrained() || persistence_save_in_progress)
		return
	if (worksite != src ? (QDELETED(from_below) || !below_ladder_worksite(user, lower) || landing() != lower || lower_ladder() != from_below || user.get_active_hand()) : !Adjacent(user))
		return
	var/obj/structure/multiz/ladder/up/hole_ladder/L = lower_ladder()
	has_ladder = FALSE
	if (L)
		qdel(L)
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
	if (has_ladder || trapdoor_shut_at(loc))
		return
	return ..()
