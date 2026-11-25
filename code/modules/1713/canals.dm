// Canals and pound locks (docs/canals.md).
//
// A dug trench next to water floods and boats can use it (trench.dm). Water
// keeps to gravity: a trench floods only from water standing at least as high
// as its own ground, so a canal can't climb a hill by itself. Where the ground
// steps up or down, the canal water sits at different levels and no boat can
// cross the step.
//
// A pound lock built on a flooded canal tile at a step lets boats pass. Its
// chamber stands at the level of one side or the other; boats move between it
// and the side whose level it matches. Working the lock fills or empties the
// chamber to the other side's level.
//
// An aqueduct channel beside a dry trench floods it too, so a summit pound can
// be fed from higher ground.

#define CANAL_LOCK_TIME 100

// The water level of an open water tile, for canal steps.
/proc/canal_level(turf/T)
	if (!T)
		return 0
	for (var/obj/structure/canal_lock/L in T)
		return L.chamber_level
	return terrain_height_at(T)

/proc/canal_tile(turf/T)
	return istype(T, /turf/floor/trench/flooded) || (locate(/obj/structure/canal_lock) in T)

// TRUE when a boat tries to cross closed lock gates or unequal water levels
// in a canal. Natural rivers and seas run down their own slopes and are not
// affected.
/proc/canal_step_blocked(turf/from, turf/to_turf)
	if (!from || !to_turf || from == to_turf)
		return FALSE
	if (!canal_tile(from) && !canal_tile(to_turf))
		return FALSE
	for (var/obj/structure/canal_lock/L in from)
		if (L.busy)
			return TRUE
	for (var/obj/structure/canal_lock/L in to_turf)
		if (L.busy)
			return TRUE
	return canal_level(from) != canal_level(to_turf)

// Gravity for trench flooding: water standing at W can flood dry ground at T.
/proc/canal_can_flood(turf/water, turf/T)
	if (!water || !T)
		return FALSE
	return canal_level(water) >= terrain_height_at(T)

/obj/structure/canal_lock
	name = "pound lock"
	desc = "A walled chamber with a pair of gates at each end, built where a canal steps up or down. Work it to fill or empty the chamber and lift a boat to the other level."
	icon = 'icons/obj/canal_lock.dmi'
	icon_state = "lock_low"
	density = FALSE
	anchored = TRUE
	layer = 2.2
	not_disassemblable = FALSE
	var/chamber_level = 0
	var/high = FALSE
	var/tmp/busy = FALSE

/obj/structure/canal_lock/persistence_runtime_var(key)
	return key == "busy" || ..()

/obj/structure/canal_lock/New()
	..()
	spawn_level()

// Facing the upper pound, the chamber starts low.
/obj/structure/canal_lock/proc/spawn_level()
	var/list/levels = side_levels()
	if (levels)
		dir = levels[3]
		chamber_level = high ? levels[2] : levels[1]
	update_icon()

// list(low level, high level, dir of the high side), from the water beside it.
/obj/structure/canal_lock/proc/side_levels()
	var/turf/T = get_turf(src)
	if (!T)
		return null
	var/low = null
	var/hi = null
	var/hi_dir = dir
	for (var/d in cardinal)
		var/turf/W = get_step(T, d)
		if (!is_open_water(W) || (locate(/obj/structure/canal_lock) in W))
			continue
		var/level = terrain_height_at(W)
		if (isnull(low) || level < low)
			low = level
		if (isnull(hi) || level > hi)
			hi = level
			hi_dir = d
	if (isnull(low))
		return null
	return list(low, hi, hi_dir)

/obj/structure/canal_lock/update_icon()
	icon_state = high ? "lock_high" : "lock_low"

/obj/structure/canal_lock/examine(mob/user)
	..()
	var/list/levels = side_levels()
	if (!levels || levels[1] == levels[2])
		to_chat(user, SPAN_NOTICE("There is no step here: the water is level on both sides."))
		return
	to_chat(user, SPAN_NOTICE("The chamber stands [high ? "high, open to the upper pound" : "low, open to the lower pound"]."))

/obj/structure/canal_lock/attack_hand(mob/user)
	if (busy)
		to_chat(user, SPAN_WARNING("The lock is already being worked."))
		return
	var/list/levels = side_levels()
	if (!levels || levels[1] == levels[2])
		to_chat(user, SPAN_WARNING("There is no step here to lift a boat over."))
		return
	busy = TRUE
	user.visible_message(SPAN_NOTICE("[user] shuts the gates and opens the paddles of \the [src]."), SPAN_NOTICE("You shut the gates and wind open the paddles."))
	flick(high ? "lock_emptying" : "lock_filling", src)
	var/done = do_after(user, CANAL_LOCK_TIME, src)
	if (QDELETED(src))
		return
	busy = FALSE
	if (!done)
		to_chat(user, SPAN_WARNING("The lock cycle is interrupted. The chamber stays at its previous level."))
		return
	levels = side_levels()
	if (!levels || levels[1] == levels[2])
		to_chat(user, SPAN_WARNING("The lock cycle is cancelled: the two pounds are no longer connected at different levels. The chamber stays at its previous level."))
		return
	set_high(!high, levels)
	user.visible_message(SPAN_NOTICE("\The [src] [high ? "fills" : "empties"] and its [high ? "upper" : "lower"] gates swing open."))

/obj/structure/canal_lock/proc/set_high(state, list/levels)
	if (!levels)
		levels = side_levels()
	high = state
	if (levels)
		chamber_level = high ? levels[2] : levels[1]
	update_icon()
	return TRUE

#undef CANAL_LOCK_TIME
