// ============================================================
// Submarine torpedo tubes (docs/vessel-entries.md, phase 3)
// ------------------------------------------------------------
// A torpedo tube fitted in a submarine's bow sections (sheet fitting "T")
// fires along her heading, not the way it was trained on deck. Submerged she
// fires from periscope depth: the torpedo runs on the surface straight above
// her bow, or along the sea layer when something floats there, where it can
// strike another submerged boat.
//
// The tube is also a way out for a diver: an empty tube floods and a sealed
// diver squeezes out of its muzzle onto the seabed. It is slow, one diver at
// a time, and the tube cannot fire or be loaded meanwhile. Coming back in
// needs the crew to have opened the outer door for divers; a diver at a shut
// door can only hammer on it. The tube blows dry with bank air like the
// lock-out chamber, or is pumped out by hand.
// ============================================================

#define SUB_TUBE_LOCK_TIME (20 SECONDS)
#define SUB_TUBE_PUMP_TIME (40 SECONDS)
#define SUB_TUBE_KNOCK_COOLDOWN (5 SECONDS)

/obj/structure/torpedo_tube
	// Submarine tubes: TRUE while the crew keep the outer door open for divers.
	var/outer_open = FALSE
	var/tmp/diver_in_tube = FALSE
	var/tmp/last_knock = -1000

// The submarine this tube is fitted in, or null.
/obj/structure/torpedo_tube/proc/sub_boat()
	return isturf(loc) ? submarine_at(loc) : null

// The direction a torpedo leaves this tube.
/obj/structure/torpedo_tube/proc/fire_dir()
	var/obj/structure/vehicleparts/axis/ship/submarine/B = sub_boat()
	return B ? B.dir : dir

// The first cell past her bow straight ahead of the tube, on her own level,
// or null when the tube does not stand in her bow sections.
/obj/structure/torpedo_tube/proc/sub_bow_cell(obj/structure/vehicleparts/axis/ship/submarine/B)
	var/turf/T = get_step(get_turf(src), B.dir)
	if (!T || submarine_at(T) == B)
		return null
	return T

// Where a submarine's torpedo starts its run.
/obj/structure/torpedo_tube/proc/sub_tube_muzzle(obj/structure/vehicleparts/axis/ship/submarine/B)
	var/turf/T = sub_bow_cell(B)
	if (!T || !B.submerged)
		return T
	var/turf/up = locate(T.x, T.y, multiz_level_above(T.z))
	if (up && torpedo_water(up) && !up.iscovered())
		return up
	return T

// Why a submarine's tube cannot fire, or null.
/obj/structure/torpedo_tube/proc/sub_tube_problem(obj/structure/vehicleparts/axis/ship/submarine/B)
	if (!sub_bow_cell(B))
		return "A submarine's torpedo tube fires only from her bow sections."
	if (diver_in_tube)
		return "Someone is in \the [src]."
	return null

// The tube's hand hook (torpedoes.dm). TRUE when handled here.
/obj/structure/torpedo_tube/proc/sub_tube_attack_hand(mob/living/human/H)
	var/obj/structure/vehicleparts/axis/ship/submarine/B = sub_boat()
	if (!B || !anchored || !istype(H))
		return FALSE
	if (H.travel_held())
		return TRUE
	var/turf/here = get_turf(H)
	if (!here || !here.iscovered())
		// From the seabed.
		if (!B.submerged)
			return FALSE
		if (outer_open && !loaded && !diver_in_tube)
			tube_lock_in(H)
		else
			tube_knock(H)
		return TRUE
	if (!B.submerged)
		return FALSE
	var/list/options = list("Fire", "Lock out through the tube (diving suit)", outer_open ? "Shut the outer door" : "Open the outer door for divers", "Cancel")
	var/choice = WWinput(H, "The torpedo tube.", "Torpedo tube", "Cancel", options)
	if (!choice || choice == "Cancel" || QDELETED(src) || !Adjacent(H) || H.incapacitated())
		return TRUE
	switch (choice)
		if ("Fire")
			fire(H)
		if ("Lock out through the tube (diving suit)")
			tube_lock_out(H)
		if ("Shut the outer door", "Open the outer door for divers")
			set_outer_open(!outer_open)
			H.visible_message(SPAN_NOTICE("[H] [outer_open ? "opens" : "shuts"] the outer door of \the [src]."))
	return TRUE

/obj/structure/torpedo_tube/proc/set_outer_open(open)
	outer_open = !!open
	playsound(loc, 'sound/effects/door_lock_unlock.ogg', 50)

// The open seabed a diver leaves the tube onto, or null.
/obj/structure/torpedo_tube/proc/tube_exit()
	var/obj/structure/vehicleparts/axis/ship/submarine/B = sub_boat()
	var/turf/T = B ? sub_bow_cell(B) : null
	if (!T || !sea_layer_cell(T) || T.iscovered() || T.density)
		return null
	for (var/atom/movable/A in T)
		if (A.density)
			return null
	return T

// Why a diver cannot use the tube now, or null.
/obj/structure/torpedo_tube/proc/tube_lock_refusal()
	if (loaded)
		return "\The [src] has a torpedo in it."
	if (diver_in_tube)
		return "Someone is already in \the [src]."
	return null

/obj/structure/torpedo_tube/proc/tube_lock_out(mob/living/human/H)
	var/problem = tube_lock_refusal()
	if (!problem && !H.can_walk_seabed())
		problem = "You would drown in the flooded tube. You need a sealed diving suit."
	if (!problem && !tube_exit())
		problem = "Rock or wreckage blocks the muzzle of \the [src]."
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return FALSE
	diver_in_tube = TRUE
	H.visible_message(SPAN_NOTICE("[H] squeezes head first into \the [src] and the rear door is shut behind them."))
	var/ok = do_after(H, SUB_TUBE_LOCK_TIME, src)
	diver_in_tube = FALSE
	var/obj/structure/vehicleparts/axis/ship/submarine/B = sub_boat()
	var/turf/exit = tube_exit()
	if (!ok || QDELETED(src) || !B || !B.submerged || !exit || loaded || H.travel_held() || !H.can_walk_seabed())
		return FALSE
	H.forceMove(exit)
	to_chat(H, SPAN_NOTICE("The tube floods, the outer door swings open and you pull yourself out onto the seabed."))
	return TRUE

/obj/structure/torpedo_tube/proc/tube_lock_in(mob/living/human/H)
	var/problem = tube_lock_refusal()
	if (!problem && !outer_open)
		problem = "The outer door of \the [src] is shut."
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return FALSE
	var/obj/structure/vehicleparts/axis/ship/submarine/B = sub_boat()
	var/blow = B && B.air_bank >= SUB_AIR_LOCKIN_COST
	diver_in_tube = TRUE
	to_chat(H, SPAN_NOTICE("You squeeze into \the [src] feet first and pull the outer door shut behind you[blow ? "" : ". The air bank is empty, so the crew pump it out by hand"]..."))
	var/ok = do_after(H, blow ? SUB_TUBE_LOCK_TIME : SUB_TUBE_PUMP_TIME, src)
	diver_in_tube = FALSE
	B = sub_boat()
	if (!ok || QDELETED(src) || !B || !B.submerged || !Adjacent(H) || loaded || H.travel_held())
		return FALSE
	if (blow)
		B.blow_chamber()
	set_outer_open(FALSE)
	H.forceMove(get_turf(src))
	B.crew_message(SPAN_NOTICE("[H] crawls out of the breech of \the [src]."))
	return TRUE

/obj/structure/torpedo_tube/proc/tube_knock(mob/living/human/H)
	to_chat(H, SPAN_WARNING("The outer door of \the [src] is shut[loaded ? " and there is a torpedo in it" : ""]. You hammer on the hull for the crew."))
	if (world.time < last_knock + SUB_TUBE_KNOCK_COOLDOWN)
		return FALSE
	last_knock = world.time
	playsound(loc, 'sound/effects/clang.ogg', 60)
	var/obj/structure/vehicleparts/axis/ship/submarine/B = sub_boat()
	if (B)
		B.crew_message(SPAN_WARNING("Someone hammers on the hull by \the [src]."))
	return TRUE

#undef SUB_TUBE_LOCK_TIME
#undef SUB_TUBE_PUMP_TIME
#undef SUB_TUBE_KNOCK_COOLDOWN
