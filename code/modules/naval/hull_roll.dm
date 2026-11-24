// Storm capsize starts with a physical leeward deck slide, then the ordinary
// whole-hull depth movement. Never rotate individual covers out of their
// logical cells: a 2D built cover cannot stand on its side while still owning
// the same rooms, collision and hatches.
#define HULL_ROLL_SLIDE_TILES 4
#define HULL_ROLL_HEEL_TIME (3 SECONDS)

// Only the owner's actual surface deck participates, not cargo, holders,
// occupants on other z-levels, people secured to fittings, or roofed space.
/datum/craft_body/built/proc/hull_roll_exposed(turf/T)
	return contains(T) && is_open_sea(T) && hull_floor_in(T) && !(locate(/obj/roof) in T)

// A roll slides past ordinary people and over the outer rail, but cannot pass
// walls, machinery, doors, railings within the deck or onto another vessel.
/proc/hull_roll_clear(turf/T, lee, overboard = FALSE, leaving = FALSE)
	if (!T || T.density || !is_open_sea(T))
		return FALSE
	if (overboard && !leaving && (hull_floor_in(T) || craft_at(T)))
		return FALSE
	for (var/obj/O in T)
		if (O.loc != T || !O.density || QDELETED(O))
			continue
		var/obj/structure/railing/built/gunwale/R = O
		if (istype(R))
			// The rails at either end of a tile do not block travel along
			// that tile unless they actually cross the line of the slide.
			if (leaving ? R.dir != lee : R.dir != turn(lee, 180))
				continue
			if (leaving && overboard && !hull_gun_port(R))
				continue
		return FALSE
	return TRUE

// Show a single wash/heel pulse using independent appearances on the real
// planks, so riders, lighting and collision offsets retain their owners.
// The overlay rides with its plank if depth changes before it is cleared.
/datum/craft_body/built/proc/show_storm_heel(list/deck, lee)
	var/image/wash = image(icon = 'icons/effects/hull_awash.dmi', icon_state = "awash")
	var/matrix/tilt = matrix()
	tilt.Scale(1, 0.7)
	tilt.Translate(0, 5)
	tilt.Turn(dir2angle(lee))
	wash.transform = tilt
	wash.alpha = 220
	var/list/planks = list()
	for (var/turf/T in deck)
		if (!hull_roll_exposed(T))
			continue
		for (var/obj/covers/C in T)
			if (hull_floor_plank(C, T))
				planks += C
				C.overlays += wash
				break
	if (planks.len)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(hull_roll_clear_heel), planks, wash), HULL_ROLL_HEEL_TIME)

/proc/hull_roll_clear_heel(list/planks, image/wash)
	for (var/obj/covers/C in planks)
		if (!QDELETED(C))
			C.overlays -= wash

/datum/craft_body/built/proc/hull_roll_slide(turf/from, lee)
	. = from
	for (var/i = 1 to HULL_ROLL_SLIDE_TILES)
		var/turf/T = get_step(., lee)
		var/overboard = !contains(T)
		if (!hull_roll_clear(., lee, overboard, TRUE) || !hull_roll_clear(T, lee, overboard))
			break
		if (overboard)
			. = T
			break
		if (!hull_roll_exposed(T))
			break
		. = T

/datum/hull_ledger/proc/apply_storm_roll(lee)
	if (!(lee in cardinal) || !craft || craft.carrier || craft.carried.len || craft.grapple || craft.ticket)
		return 0
	var/datum/craft_body/built/B = craft.body
	if (!istype(B) || !B.placed() || B.moving)
		return 0
	// Snapshot first: overlapping mobs are listed under several turfs in
	// BYOND. Each body gets one impulse, based on its own centre tile.
	var/list/crew = list()
	var/list/deck = B.cells()
	B.show_storm_heel(deck, lee)
	for (var/turf/T in deck)
		if (!B.hull_roll_exposed(T))
			continue
		for (var/mob/living/L in T)
			if (L.loc == T && !QDELETED(L) && L.stat != DEAD && !L.buckled && !L.travel_held())
				crew[L] = T
	var/moved = 0
	for (var/mob/living/L in crew)
		var/turf/from = crew[L]
		if (QDELETED(L) || L.stat == DEAD || L.loc != from || L.buckled || L.travel_held() || !B.hull_roll_exposed(from))
			continue
		var/turf/destination = B.hull_roll_slide(from, lee)
		if (destination != from && L.forceMove(destination) && !QDELETED(L) && L.loc == destination)
			moved++
			if (!B.contains(destination))
				to_chat(L, SPAN_DANGER("The rolling ship throws you overboard!"))
			else
				to_chat(L, SPAN_WARNING("You slide across the heeling deck!"))
		if (!QDELETED(L) && L.stat != DEAD)
			L.Weaken(3)
	return moved

#undef HULL_ROLL_HEEL_TIME
#undef HULL_ROLL_SLIDE_TILES
