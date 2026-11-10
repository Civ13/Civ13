// ============================================================
// Freight routes (orbital stations, stage E, 2013)
// ------------------------------------------------------------
// A freight dispatcher beside a launch pad runs that pad as a standing
// route for its party, with nobody at the pad:
//
// - It loads any cargo freighter standing at the pad from the crates within
//   one tile of the dispatcher (what the hold takes), so a belt or a crew can
//   fill the crates whenever they like.
// - Once the hold carries the set load and the tank is full, it launches the
//   freighter to the pad's world for its party, exactly as a crew would.
// - It never wakes a sleeping world: it waits until the destination is up.
//
// Build the next freighter at the pad and the route carries on. The party,
// the load and the pause switch are plain saved values; nothing here is a
// world.time stamp.
// ============================================================

#define ORBIT_ROUTE_RANGE 2

var/global/list/orbit_freight_dispatchers = list()

/obj/structure/freight_dispatcher
	name = "freight dispatcher"
	desc = "A rugged control box with a cargo scanner. Beside a launch pad, it loads cargo freighters from crates next to it and launches them for its party once their hold is full, with nobody at the pad."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "steel_grid"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	// The party the route flies for, and who set it up.
	var/party = null
	var/by = null
	// Items in the hold before a launch.
	var/load = LANDER_CARGO_MAX
	var/paused = FALSE
	// Why the last launch waited, for examine. Process-local.
	var/tmp/waiting = null
	var/tmp/dispatching = FALSE

/obj/structure/freight_dispatcher/New()
	..()
	orbit_freight_dispatchers |= src
	processing_objects |= src

/obj/structure/freight_dispatcher/Destroy()
	orbit_freight_dispatchers -= src
	processing_objects -= src
	return ..()

/obj/structure/freight_dispatcher/persistence_runtime_var(key)
	return (key in list("waiting", "dispatching")) || ..()

/obj/structure/freight_dispatcher/examine(mob/user)
	..()
	if (!party)
		to_chat(user, SPAN_NOTICE("No route is set up. Use it to run this pad for your party."))
		return
	to_chat(user, SPAN_NOTICE("Route of [party_train_party_name(party)]: launches each freighter at the pad once it holds [load] item\s.[paused ? " Paused." : ""]"))
	if (waiting && !paused)
		to_chat(user, SPAN_WARNING("Waiting: [waiting]"))

/obj/structure/freight_dispatcher/attack_hand(mob/living/human/user)
	if (!istype(user) || !user.client)
		return
	var/mine = party_train_party_of(user)
	if (!mine)
		to_chat(user, SPAN_WARNING("You have no party to run a route for."))
		return
	if (party && party != mine)
		to_chat(user, SPAN_WARNING("\The [src] runs a route for [party_train_party_name(party)]."))
		return
	var/list/options = list(party ? "Set the load" : "Set up a route")
	if (party)
		options += list(paused ? "Resume" : "Pause", "Clear the route")
	options += "Cancel"
	var/choice = WWinput(user, party ? "Route of [party_train_party_name(party)]: launch at [load] item\s[paused ? ", paused" : ""]." : "Run this pad as a freight route for [party_train_party_name(mine)]?", capitalize(name), "Cancel", options)
	if (choice == "Cancel" || QDELETED(src) || !in_range(src, user) || user.incapacitated() || (party && party != mine))
		return
	switch (choice)
		if ("Set up a route", "Set the load")
			var/list/loads = list()
			for (var/n in 1 to LANDER_CARGO_MAX)
				loads += "[n]"
			var/pick = player_input(user, "Launch each freighter once its hold carries how many items?", capitalize(name), "[load]", "anything", loads, TRUE)
			if (!pick || QDELETED(src) || !in_range(src, user) || (party && party != mine))
				return
			set_route(user, text2num(pick))
			to_chat(user, SPAN_NOTICE("\The [src] will launch each freighter at the pad once it holds [load] item\s."))
		if ("Pause", "Resume")
			paused = !paused
			to_chat(user, SPAN_NOTICE(paused ? "You pause the route." : "You resume the route."))
		if ("Clear the route")
			party = null
			by = null
			paused = FALSE
			to_chat(user, SPAN_NOTICE("You clear the route."))

/obj/structure/freight_dispatcher/proc/set_route(mob/living/human/user, n)
	party = party_train_party_of(user)
	by = user && user.client ? user.client.ckey : null
	load = Clamp(round(n), 1, LANDER_CARGO_MAX)
	paused = FALSE

// The freighter standing at the pad beside this dispatcher, or null.
/obj/structure/freight_dispatcher/proc/freighter()
	for (var/obj/structure/crewed_lander/freighter/F in orbit_freighters)
		if (!QDELETED(F) && isturf(F.loc) && F.z == z && get_dist(F, src) <= ORBIT_ROUTE_RANGE && !F.launching && F.find_pad())
			return F
	return null

// Moves what the hold takes from the crates beside the dispatcher into F.
// Returns how many items it loaded.
/obj/structure/freight_dispatcher/proc/load_freighter(obj/structure/crewed_lander/freighter/F)
	. = 0
	for (var/obj/structure/closet/crate/C in range(1, src))
		if (C.opened)
			continue
		for (var/obj/item/I in C.contents)
			if (length(F.hold()) >= load || F.stow_refusal(I))
				continue
			I.forceMove(F)
			.++

// Null when F may fly on this route now, otherwise why not.
/obj/structure/freight_dispatcher/proc/route_refusal(obj/structure/crewed_lander/freighter/F)
	if (!F)
		return "No freighter stands at the pad."
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = F.find_pad()
	if (!pad)
		return "No freighter stands at the pad."
	var/reason = pad.closed_reason()
	if (reason)
		return reason
	if (length(F.hold()) < load)
		return "The hold carries [length(F.hold())] of [load] item\s."
	if (F.propellant < F.propellant_needed)
		return "\The [F] needs [F.propellant_needed] units of rocket propellant or methalox ([F.propellant] loaded)."
	if (persistence_save_active())
		return "The world is saving."
	if (shard_group.peers[pad.destination] && shard_group.peers[pad.destination]["state"] != "UP")
		return "[pad.destination_name()] is asleep; the route flies once it is up."
	return F.vehicle_refusal(pad.destination)

/obj/structure/freight_dispatcher/process()
	if (!party || paused || dispatching)
		return
	var/obj/structure/crewed_lander/freighter/F = freighter()
	if (F)
		load_freighter(F)
	waiting = route_refusal(F)
	if (!waiting)
		dispatch(F)

// Launches F for the route's party without sleeping the caller.
/obj/structure/freight_dispatcher/proc/dispatch(obj/structure/crewed_lander/freighter/F)
	set waitfor = FALSE
	dispatching = TRUE
	. = route_launch(F)
	dispatching = FALSE

// Launches F now. Returns null once it left, or why it did not.
/obj/structure/freight_dispatcher/proc/route_launch(obj/structure/crewed_lander/freighter/F)
	var/reason = route_refusal(F)
	if (!reason)
		reason = F.launch_freight(F.find_pad(), null, party, by)
	waiting = reason
	if (!reason)
		visible_message(SPAN_NOTICE("\The [src] chirps: freighter away for [party_train_party_name(party)]."))
	return reason

#undef ORBIT_ROUTE_RANGE
