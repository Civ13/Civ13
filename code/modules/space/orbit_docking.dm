// ============================================================
// Station visits (orbital stations, stage E, 2013)
// ------------------------------------------------------------
// Each station lives on its own plane, so until now only its own party ever
// stood aboard. A docking port lets other parties visit:
//
// - A port belongs to the station whose plane it stands on. Its owners
//   choose who may dock: nobody but themselves, the parties on their guest
//   list, or everyone.
// - From any port, a player can ferry across to another station's port that
//   welcomes their party, and from there home again (to their own port, or
//   their station's hatch when they have no port).
// - Ports also trade: anyone at a port may leave a parcel for its station, and
//   the owners may leave parcels for a guest party. Each party collects what
//   is addressed to it at that port.
//
// Visitors keep every other party check (thrusters, pods, decks, sectors and
// consoles stay the owners'). Nothing here is a world.time stamp.
// ============================================================

#define ORBIT_DOCKING_AGE 8
#define ORBIT_DOCKING_DELAY 50
#define ORBIT_DOCKING_GUESTS 10
#define ORBIT_DOCKING_PARCELS 20

var/global/list/orbit_docking_ports = list()

/obj/structure/docking_port
	name = "docking port"
	desc = "A ferry collar with a hatch for visiting crews and a small cargo hatch for parcels. Its station's owners choose who may dock."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "steel_grid"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	layer = TURF_LAYER + 0.2
	// "owners", "guests" or "everyone".
	var/welcome = "owners"
	// Parties on the guest list.
	var/list/guests = list()

/obj/structure/docking_port/New()
	..()
	orbit_docking_ports |= src

/obj/structure/docking_port/Destroy()
	orbit_docking_ports -= src
	for (var/obj/item/station_parcel/P in contents)
		P.forceMove(get_turf(src))
	return ..()

// The party whose station this port belongs to, or null.
/obj/structure/docking_port/proc/owner()
	return isturf(loc) ? orbit_station_party(z) : null

// TRUE when party may dock here.
/obj/structure/docking_port/proc/welcomes(party)
	var/owner = owner()
	if (!owner || !party)
		return FALSE
	if (party == owner || welcome == "everyone")
		return TRUE
	return welcome == "guests" && (party in guests)

/obj/structure/docking_port/examine(mob/user)
	..()
	var/owner = owner()
	if (!owner)
		to_chat(user, SPAN_WARNING("It stands on no station. Set it up on your station's plane."))
		return
	var/mode = welcome == "everyone" ? "every party" : (welcome == "guests" ? "[party_train_party_name(owner)] and [length(guests)] guest part[length(guests) == 1 ? "y" : "ies"]" : "only [party_train_party_name(owner)]")
	to_chat(user, SPAN_NOTICE("Station of [party_train_party_name(owner)]. It welcomes [mode]. Parcels waiting: [length(parcels())]."))

/obj/structure/docking_port/proc/parcels(party = null)
	var/list/found = list()
	for (var/obj/item/station_parcel/P in contents)
		if (!party || P.for_party == party)
			found += P
	return found

// Null when user may use the port at all, otherwise why not.
/obj/structure/docking_port/proc/use_refusal(mob/living/human/user)
	if (!orbit_world())
		return "A docking port only works in orbit."
	if (!map || map.ordinal_age < ORBIT_DOCKING_AGE)
		return "Docking ports work from 2013."
	if (!owner())
		return "\The [src] stands on no station."
	if (!party_train_party_of(user))
		return "You have no party to dock for."
	return null

/obj/structure/docking_port/attack_hand(mob/living/human/user)
	if (!istype(user) || !user.client)
		return
	var/reason = use_refusal(user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	var/party = party_train_party_of(user)
	var/is_owner = party == owner()
	var/list/options = list("Ferry to another station")
	if (welcomes(party))
		options += "Leave a parcel"
	if (length(parcels(party)))
		options += "Collect parcels"
	if (is_owner)
		options += list("Who may dock", "Add a guest party", "Remove a guest party")
	options += "Cancel"
	var/choice = WWinput(user, "Docking port of [party_train_party_name(owner())].", "Docking port", "Cancel", options)
	if (QDELETED(src) || !user.client || !in_range(src, user) || user.incapacitated())
		return
	switch (choice)
		if ("Ferry to another station")
			ferry_prompt(user)
		if ("Leave a parcel")
			leave_parcel_prompt(user)
		if ("Collect parcels")
			var/count = collect_parcels(user)
			to_chat(user, SPAN_NOTICE(count ? "You collect [count] parcel\s." : "Nothing is waiting for you."))
		if ("Who may dock")
			var/mode = WWinput(user, "Who may dock at your station?", "Docking port", "Cancel", list("Only us", "Our guests", "Everyone", "Cancel"))
			if (QDELETED(src) || party_train_party_of(user) != owner())
				return
			switch (mode)
				if ("Only us")
					welcome = "owners"
				if ("Our guests")
					welcome = "guests"
				if ("Everyone")
					welcome = "everyone"
			if (mode != "Cancel")
				to_chat(user, SPAN_NOTICE("The port now welcomes [lowertext(mode)]."))
		if ("Add a guest party")
			var/list/choices = list()
			for (var/other in orbit_docking_parties())
				if (other != owner() && !(other in guests))
					choices[party_train_party_name(other)] = other
			if (!choices.len)
				to_chat(user, SPAN_WARNING("No other station has a docking port to invite."))
				return
			var/pick = input(user, "Invite which party?", "Docking port") as null|anything in choices
			if (!pick || QDELETED(src) || party_train_party_of(user) != owner())
				return
			if (!add_guest(choices[pick]))
				to_chat(user, SPAN_WARNING("The guest list is full."))
				return
			to_chat(user, SPAN_NOTICE("[pick] may now dock[welcome == "guests" ? "" : " once the port welcomes guests"]."))
		if ("Remove a guest party")
			var/list/choices = list()
			for (var/other in guests)
				choices[party_train_party_name(other)] = other
			var/pick = input(user, "Remove which party?", "Docking port") as null|anything in choices
			if (pick && !QDELETED(src) && party_train_party_of(user) == owner())
				guests -= choices[pick]

/obj/structure/docking_port/proc/add_guest(party)
	if (!party_train_valid_party(party) || party == owner())
		return FALSE
	if (party in guests)
		return TRUE
	if (length(guests) >= ORBIT_DOCKING_GUESTS)
		return FALSE
	guests += party
	return TRUE

// Parties with a docking port on their station.
/proc/orbit_docking_parties()
	var/list/parties = list()
	for (var/obj/structure/docking_port/P in orbit_docking_ports)
		var/owner = QDELETED(P) ? null : P.owner()
		if (owner)
			parties |= owner
	return parties

// Where a party member can ferry to from here, as label = turf.
/obj/structure/docking_port/proc/ferry_choices(party)
	var/list/choices = list()
	var/home_listed = FALSE
	for (var/obj/structure/docking_port/P in orbit_docking_ports)
		if (P == src || QDELETED(P) || !isturf(P.loc) || P.owner() == owner() || !P.welcomes(party))
			continue
		var/owner = P.owner()
		if (owner == party)
			if (home_listed)
				continue
			home_listed = TRUE
			choices["Home: your station"] = get_turf(P)
		else
			choices["Station of [party_train_party_name(owner)]"] = get_turf(P)
	if (!home_listed && party != owner())
		var/obj/structure/region_gate/station_hatch/H = orbit_station_hatch(party)
		if (H && isturf(H.loc))
			choices["Home: your station"] = get_turf(H)
	return choices

/obj/structure/docking_port/proc/ferry_prompt(mob/living/human/user)
	var/party = party_train_party_of(user)
	var/list/choices = ferry_choices(party)
	if (!choices.len)
		to_chat(user, SPAN_WARNING("No other station welcomes [party_train_party_name(party)]."))
		return
	var/pick = input(user, "Ferry to which station?", "Docking port") as null|anything in choices
	if (!pick || QDELETED(src) || !in_range(src, user))
		return
	var/reason = ferry(user, pick)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))

// Ferries user to the choice labelled pick. Returns null once they crossed,
// or why they did not.
/obj/structure/docking_port/proc/ferry(mob/living/human/user, pick)
	to_chat(user, SPAN_NOTICE("You strap into the ferry collar and push off..."))
	if (!do_after(user, ORBIT_DOCKING_DELAY, src) || QDELETED(src))
		return "The ferry was called off."
	return cross(user, pick)

// Moves user to the choice labelled pick, checked again now.
/obj/structure/docking_port/proc/cross(mob/living/human/user, pick)
	var/party = party_train_party_of(user)
	var/list/choices = ferry_choices(party)
	var/turf/target = choices[pick]
	if (!target)
		return "That station no longer welcomes you."
	var/turf/landing = orbit_freight_beside(target) || target
	user.visible_message(SPAN_NOTICE("[user] ferries away from \the [src]."))
	user.forceMove(landing)
	user.visible_message(SPAN_NOTICE("[user] arrives by ferry."))
	log_game("Docking port: [key_name(user)] of [party] ferried to [landing.x],[landing.y],[landing.z] ([pick]).")
	return null

// ---------------------------------------------------------------- parcels

/obj/item/station_parcel
	name = "parcel"
	desc = "A sealed cargo bag waiting at a docking port."
	icon = 'icons/obj/storage.dmi'
	icon_state = "densecrate"
	w_class = ITEM_SIZE_HUGE
	var/for_party = null

/obj/structure/docking_port/proc/leave_parcel_prompt(mob/living/human/user)
	var/obj/item/I = user.get_active_hand()
	if (!I)
		to_chat(user, SPAN_WARNING("Hold what you want to leave."))
		return
	var/party = party_train_party_of(user)
	var/to_party = owner()
	if (party == owner())
		var/list/choices = list()
		for (var/other in guests)
			choices[party_train_party_name(other)] = other
		if (!choices.len)
			to_chat(user, SPAN_WARNING("Add a guest party first to leave parcels for them."))
			return
		var/pick = input(user, "Leave \the [I] for which party?", "Docking port") as null|anything in choices
		if (!pick)
			return
		to_party = choices[pick]
	if (QDELETED(src) || !in_range(src, user) || user.get_active_hand() != I)
		return
	var/reason = leave_parcel(user, I, to_party)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	to_chat(user, SPAN_NOTICE("You seal \the [I] in a parcel for [party_train_party_name(to_party)]."))

// Wraps I as a parcel for party. Returns null when it did, or why not.
/obj/structure/docking_port/proc/leave_parcel(mob/living/human/user, obj/item/I, party)
	if (!istype(I) || istype(I, /obj/item/station_parcel))
		return "That cannot be sent as a parcel."
	if (length(parcels()) >= ORBIT_DOCKING_PARCELS)
		return "The cargo hatch is full."
	if (party != owner() && !(party in guests))
		return "\The [src] does not send parcels to [party_train_party_name(party)]."
	if (user && !user.drop_from_inventory(I))
		return "You cannot let go of \the [I]."
	var/obj/item/station_parcel/P = new(src)
	P.for_party = party
	P.name = "parcel for [party_train_party_name(party)]"
	I.forceMove(P)
	return null

// Unwraps every parcel for user's party beside them. Returns how many.
/obj/structure/docking_port/proc/collect_parcels(mob/living/human/user)
	var/party = party_train_party_of(user)
	var/turf/T = get_turf(user)
	var/count = 0
	for (var/obj/item/station_parcel/P in parcels(party))
		for (var/atom/movable/A in P.contents)
			A.forceMove(T)
		qdel(P)
		count++
	return count

#undef ORBIT_DOCKING_AGE
#undef ORBIT_DOCKING_DELAY
#undef ORBIT_DOCKING_GUESTS
#undef ORBIT_DOCKING_PARCELS
