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
// - Boarding raids: a party can force a docking at a station that does not
//   welcome it, but only while some of its owners are online (the train raid
//   rule). The crossing takes 30 seconds and the owners are warned.
//
// Visitors keep every other party check (thrusters, pods, decks, sectors and
// consoles stay the owners'). Nothing here is a world.time stamp.
//
// Berths for rockets (from 1969, the first orbital flights):
//
// - A port fitted on an outer hatch has a berth: the open space beyond the
//   hatch, where a rocket's capsule docks with its deck against the hatch.
//   Every station plan has a docking airlock with one (station_plan.dm).
// - The orbit world tells the other worlds which berths are free
//   (orbit_docking_advertisements, in its shard status). A launch to orbit
//   picks a free berth that welcomes the crew's party, or none at all; a
//   launch is refused at a berth that is no longer free.
// - Either side may bar the port: the station's crew from inside, so nobody
//   comes aboard from the berth, or a docked crew from outside, so nobody
//   from the station comes into their capsule.
// ============================================================

#define ORBIT_DOCKING_AGE 8
#define ORBIT_DOCKING_DELAY 50
#define ORBIT_DOCKING_FORCE_DELAY 300
#define ORBIT_DOCKING_GUESTS 10
#define ORBIT_DOCKING_PARCELS 20
// Ports the orbit world tells other worlds about, at most.
#define ORBIT_DOCKING_ADVERTISED 24

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
	// Names this port to rockets launched from other worlds; plain text.
	var/port_id = ""
	// Barred by the station's crew (nobody comes aboard from the berth) or by
	// a docked crew (nobody from the station comes into their capsule).
	var/barred_inside = FALSE
	var/barred_outside = FALSE

/obj/structure/docking_port/New()
	..()
	orbit_docking_ports |= src

// A new port is named once; a restored one keeps its saved name (restore_contract.dm).
/obj/structure/docking_port/on_runtime_spawn()
	..()
	if (!orbit_docking_valid_id(port_id))
		port_id = "port-[num2text(world.realtime, 20)]-[rand(100000, 999999)]"

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
	to_chat(user, SPAN_NOTICE(berth_text()))

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
	if (!owner())
		return "\The [src] stands on no station."
	return null

// TRUE once ferries, boarding and parcels work (2013); berths work from 1969.
/proc/orbit_docking_visits_open()
	return map && map.ordinal_age >= ORBIT_DOCKING_AGE

/obj/structure/docking_port/attack_hand(mob/living/human/user)
	if (!istype(user) || !user.client)
		return
	var/reason = use_refusal(user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	var/party = party_train_party_of(user)
	var/is_owner = party && party == owner()
	var/list/options = list()
	var/side = bar_side(user)
	if (side == "inside")
		options += barred_inside ? "Unbar it from inside" : "Bar it from inside"
	else if (side == "outside")
		options += barred_outside ? "Unbar it from outside" : "Bar it from outside"
	if (party && orbit_docking_visits_open())
		options += "Ferry to another station"
		if (length(ferry_choices(party, TRUE)))
			options += "Force a docking"
		if (welcomes(party))
			options += "Leave a parcel"
		if (length(parcels(party)))
			options += "Collect parcels"
	if (is_owner)
		options += list("Who may dock", "Add a guest party", "Remove a guest party")
	options += "Cancel"
	var/choice = WWinput(user, "Docking port of [party_train_party_name(owner())]. [berth_text()]", "Docking port", "Cancel", options)
	if (QDELETED(src) || !user.client || !in_range(src, user) || user.incapacitated())
		return
	switch (choice)
		if ("Bar it from inside", "Unbar it from inside", "Bar it from outside", "Unbar it from outside")
			if (bar_side(user) != (findtext(choice, "inside") ? "inside" : "outside"))
				return
			set_bar(user, findtext(choice, "inside") ? "inside" : "outside", findtext(choice, "Unbar") != 1)
		if ("Ferry to another station")
			ferry_prompt(user)
		if ("Force a docking")
			ferry_prompt(user, TRUE)
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
			var/pick = player_input(user, "Invite which party?", "Docking port", null, "anything", choices, TRUE)
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
			var/pick = player_input(user, "Remove which party?", "Docking port", null, "anything", choices, TRUE)
			if (pick && !QDELETED(src) && party_train_party_of(user) == owner())
				guests -= choices[pick]


// ---------------------------------------------------------------- berths

/proc/orbit_docking_valid_id(id)
	if (!istext(id) || length(id) < 6 || length(id) > 48)
		return FALSE
	for (var/i = 1, i <= length(id), i++)
		var/c = text2ascii(id, i)
		if (!((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 45))
			return FALSE
	return TRUE

/proc/orbit_docking_port_by_id(id)
	if (!orbit_docking_valid_id(id))
		return null
	for (var/obj/structure/docking_port/P in orbit_docking_ports)
		if (!QDELETED(P) && P.port_id == id)
			return P
	return null

// The way out to the berth: from an outer hatch, the side facing open space
// (or a docked capsule's deck). 0 when the port is not on an outer hatch.
/obj/structure/docking_port/proc/outward()
	var/turf/T = loc
	if (!isturf(T) || !(locate(/obj/structure/simple_door/habitat_hatch) in T))
		return 0
	for (var/d in cardinal)
		var/turf/N = get_step(T, d)
		if (istype(N, /turf/floor/space/orbit) || istype(N, /turf/floor/lander_deck))
			return d
	return 0

// Where a docked capsule's core stands: two tiles out, so its deck touches
// the hatch. Null when the port has no berth.
/obj/structure/docking_port/proc/berth_turf()
	var/d = outward()
	if (!d)
		return null
	return get_step(get_step(loc, d), d)

// TRUE when a capsule can dock here now.
/obj/structure/docking_port/proc/berth_free()
	if (QDELETED(src) || !owner())
		return FALSE
	var/turf/B = berth_turf()
	return B && orbit_capsule_site_clear(B.x, B.y, B.z)

// The capsule docked here, or null.
/obj/structure/docking_port/proc/docked_capsule()
	var/turf/B = berth_turf()
	var/obj/structure/landed_lander/capsule/C = B ? (locate() in B) : null
	return (C && !QDELETED(C)) ? C : null

/obj/structure/docking_port/proc/berth_text()
	. = list()
	if (!outward())
		. += "It has no berth: fit it on an airlock's outer hatch for rockets to dock."
	else if (docked_capsule())
		. += "A capsule is docked at its berth."
	else if (berth_free())
		. += "Its berth is free for a rocket."
	else
		. += "Something blocks its berth."
	if (barred_inside)
		. += "It is barred from inside."
	if (barred_outside)
		. += "It is barred from outside."
	return jointext(., " ")

// "inside" when user stands on the station side, "outside" on the berth side,
// else null (on the hatch itself, or not beside it).
/obj/structure/docking_port/proc/bar_side(mob/user)
	var/d = outward()
	var/turf/T = get_turf(user)
	if (!d || !T || T == loc || get_dist(T, loc) != 1 || T.z != z)
		return null
	if (T == get_step(loc, d))
		return "outside"
	if (T == get_step(loc, turn(d, 180)))
		return "inside"
	return null

/obj/structure/docking_port/proc/set_bar(mob/user, side, barred)
	if (side == "inside")
		barred_inside = barred
	else
		barred_outside = barred
	if (user)
		user.visible_message(SPAN_NOTICE("[user] [barred ? "bars" : "unbars"] \the [src] from [side]."))
		log_game("Docking port: [key_name(user)] [barred ? "barred" : "unbarred"] the port at [x],[y],[z] from [side].")

// A bar stops anyone crossing the hatch from the side it does not guard.
/obj/structure/docking_port/CanPass(atom/movable/mover, turf/target, height = 0, air_group = 0)
	if (air_group || !ismob(mover) || (!barred_inside && !barred_outside))
		return ..()
	var/d = outward()
	if (!d || !isturf(target))
		return ..()
	if (barred_inside && target == get_step(loc, d))
		return FALSE
	if (barred_outside && target == get_step(loc, turn(d, 180)))
		return FALSE
	return ..()

// What the orbit world tells other worlds: every free berth, for launches.
/proc/orbit_docking_advertisements()
	. = list()
	if (!orbit_world())
		return
	for (var/obj/structure/docking_port/P in orbit_docking_ports)
		if (length(.) >= ORBIT_DOCKING_ADVERTISED)
			break
		var/owner = P.owner()
		if (!owner || !orbit_docking_valid_id(P.port_id) || !P.berth_free())
			continue
		var/list/guest_list = list()
		if (P.welcome == "guests")
			for (var/g in P.guests)
				if (party_train_valid_party(g))
					guest_list += g
		. += list(list("id" = P.port_id, "party" = owner, "name" = copytext("[party_train_party_name(owner)] ([dir2text(P.outward())] port)", 1, 65), "welcome" = P.welcome, "guests" = guest_list))

// A peer's advertised berths, checked field by field.
/proc/orbit_docking_clean_advertisements(list/records)
	. = list()
	if (!islist(records) || records.len > ORBIT_DOCKING_ADVERTISED)
		return
	var/list/seen = list()
	for (var/list/entry in records)
		var/id = entry["id"]
		if (!orbit_docking_valid_id(id) || seen[id] || !party_train_valid_party(entry["party"]) || !(entry["welcome"] in list("owners", "guests", "everyone")))
			continue
		seen[id] = TRUE
		var/list/guest_list = list()
		if (islist(entry["guests"]))
			for (var/g in entry["guests"])
				if (party_train_valid_party(g) && guest_list.len < ORBIT_DOCKING_GUESTS)
					guest_list += g
		. += list(list("id" = id, "party" = entry["party"], "name" = istext(entry["name"]) ? copytext(entry["name"], 1, 65) : "Space station", "welcome" = entry["welcome"], "guests" = guest_list))

// The free berths of orbit region id that welcome party, as label = port id.
/proc/orbit_docking_berth_choices(id, party)
	. = list()
	var/list/peer = shard_group && shard_group.peers[id]
	if (!islist(peer) || !islist(peer["docking_ports"]))
		return
	for (var/list/entry in peer["docking_ports"])
		var/ok = entry["welcome"] == "everyone" || (party && (entry["party"] == party || (entry["welcome"] == "guests" && (party in entry["guests"]))))
		if (!ok)
			continue
		var/label = "Dock at [entry["name"]]"
		var/n = 2
		while (.[label])
			label = "Dock at [entry["name"]] #[n++]"
		.[label] = entry["id"]
// Fits a docking port on the outer hatch of the airlock centred on centre,
// facing dir. Returns the port.
/proc/orbit_station_docking_port(turf/centre, dir)
	var/turf/T = centre ? get_step(get_step(centre, dir), dir) : null
	if (!T)
		return null
	var/obj/structure/docking_port/P = locate() in T
	if (!P)
		P = new(T)
	P.dir = dir
	return P

// TRUE while port id is still a free berth of region id that welcomes party.
/proc/orbit_docking_berth_listed(id, port, party)
	var/list/choices = orbit_docking_berth_choices(id, party)
	for (var/label in choices)
		if (choices[label] == port)
			return TRUE
	return FALSE

/obj/structure/docking_port/proc/add_guest(party)
	if (!party_train_valid_party(party) || party == owner())
		return FALSE
	if (party in guests)
		return TRUE
	if (length(guests) >= ORBIT_DOCKING_GUESTS)
		return FALSE
	guests += party
	return TRUE

// TRUE while some of this station's owners are online to defend it.
/obj/structure/docking_port/proc/crew_aboard()
	return party_members_online(owner())

// Parties with a docking port on their station.
/proc/orbit_docking_parties()
	var/list/parties = list()
	for (var/obj/structure/docking_port/P in orbit_docking_ports)
		var/owner = QDELETED(P) ? null : P.owner()
		if (owner)
			parties |= owner
	return parties

// Where a party member can ferry to from here, as label = turf. With
// forced, the stations they could board by force instead: ports that do not
// welcome them while some of their owners are online.
/obj/structure/docking_port/proc/ferry_choices(party, forced = FALSE)
	var/list/choices = list()
	if (forced)
		for (var/obj/structure/docking_port/P in orbit_docking_ports)
			if (P == src || QDELETED(P) || !isturf(P.loc))
				continue
			var/target = P.owner()
			if (!target || target == party || target == owner() || P.welcomes(party) || !P.crew_aboard())
				continue
			choices["Board [party_train_party_name(target)]"] = get_turf(P)
		return choices
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

/obj/structure/docking_port/proc/ferry_prompt(mob/living/human/user, forced = FALSE)
	var/party = party_train_party_of(user)
	var/list/choices = ferry_choices(party, forced)
	if (!choices.len)
		to_chat(user, SPAN_WARNING(forced ? "No station you could board has its crew aboard." : "No other station welcomes [party_train_party_name(party)]."))
		return
	var/pick = player_input(user, forced ? "Board which station by force?" : "Ferry to which station?", "Docking port", null, "anything", choices, TRUE)
	if (!pick || QDELETED(src) || !in_range(src, user))
		return
	var/reason = ferry(user, pick, forced)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))

// Ferries user to the choice labelled pick. Returns null once they crossed,
// or why they did not.
/obj/structure/docking_port/proc/ferry(mob/living/human/user, pick, forced = FALSE)
	var/extra = 0
	if (forced)
		var/list/targets = ferry_choices(party_train_party_of(user), TRUE)
		var/turf/T = targets[pick]
		var/target = T ? orbit_station_party(T.z) : null
		var/obj/structure/docking_port/P = T ? (locate(/obj/structure/docking_port) in T) : null
		extra = orbit_point_defence_delay(P)
		if (extra)
			to_chat(user, SPAN_DANGER("Their point-defence fire rakes the collar; this will take longer."))
		if (target)
			satellite_raid_alert(target, "Raiders from [party_train_party_name(party_train_party_of(user))] are forcing your docking port!")
		to_chat(user, SPAN_WARNING("You strap into the ferry collar and start cutting through their docking clamps..."))
	else
		to_chat(user, SPAN_NOTICE("You strap into the ferry collar and push off..."))
	if (!do_after(user, forced ? ORBIT_DOCKING_FORCE_DELAY + extra : ORBIT_DOCKING_DELAY, src) || QDELETED(src))
		return "The ferry was called off."
	return cross(user, pick, forced)

// Moves user to the choice labelled pick, checked again now.
/obj/structure/docking_port/proc/cross(mob/living/human/user, pick, forced = FALSE)
	var/party = party_train_party_of(user)
	var/list/choices = ferry_choices(party, forced)
	var/turf/target = choices[pick]
	if (!target)
		return forced ? "That station's crew has left; you cannot board it now." : "That station no longer welcomes you."
	var/turf/landing = orbit_freight_beside(target) || target
	user.visible_message(SPAN_NOTICE("[user] ferries away from \the [src]."))
	user.forceMove(landing)
	user.visible_message(forced ? SPAN_DANGER("[user] bursts in through the docking collar!") : SPAN_NOTICE("[user] arrives by ferry."))
	log_game("Docking port: [key_name(user)] of [party] [forced ? "forced a docking" : "ferried"] to [landing.x],[landing.y],[landing.z] ([pick]).")
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
		var/pick = player_input(user, "Leave \the [I] for which party?", "Docking port", null, "anything", choices, TRUE)
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
#undef ORBIT_DOCKING_FORCE_DELAY
#undef ORBIT_DOCKING_GUESTS
#undef ORBIT_DOCKING_PARCELS
#undef ORBIT_DOCKING_ADVERTISED
