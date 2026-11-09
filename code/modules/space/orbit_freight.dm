// ============================================================
// Cargo freighter (orbital stations, stage C, 2013)
// ------------------------------------------------------------
// An uncrewed freighter flies a hold of cargo to another world of the group
// without anyone riding along. It stands beside an approved launch pad like a
// crewed lander (lander.dm), burns rocket propellant or methalox
// (methalox.dm), and takes the same goods as a lander's hold. Whoever
// launches it sends it for their party:
//
// - To orbit, the cargo arrives in a crate beside the party's station hatch.
// - To any other world, it arrives beside the party's launch complex office
//   there, or at the world's usual arrival point.
// - A flight the destination refuses comes back to where it left.
//
// The flight is one payload of kind "freight" for the transfer agent. Like a
// traveller it is journaled ("fast"), so it arrives in seconds and a world
// that reloads an older save replays it: a replayed departure finds the
// freighter by its saved id and sends it again, and a replayed arrival
// unpacks the crate again. The freighter is spent on launch.
// ============================================================

#define ORBIT_FREIGHT_AGE 8
#define ORBIT_FREIGHT_PROPELLANT 200
#define ORBIT_FREIGHT_PAYLOAD_MAX 4096

var/global/list/orbit_freighters = list()

/obj/structure/crewed_lander/freighter
	name = "cargo freighter"
	desc = "An uncrewed rocket with a cargo hold and no seats. Load the hold, fill it with rocket propellant or methalox beside an approved launch pad and launch it: the cargo lands at your party's station in orbit, or by your launch complex office on another world."
	seats = 0
	cargo_max = LANDER_CARGO_MAX
	propellant_needed = ORBIT_FREIGHT_PROPELLANT
	ascent_propellant = 0
	fuels = list("rocket_propellant", "methalox")
	// Saved: names this freighter in its flight, so a world that reloads a
	// save from before the launch can find it and send it again.
	var/freight_id = null
	var/tmp/launching = FALSE

/obj/structure/crewed_lander/freighter/New()
	..()
	orbit_freighters |= src
	if (!freight_id)
		freight_id = "[shard_group && shard_group.region ? shard_group.region : "world"]-[num2text(world.realtime, 20)]-[rand(1000, 9999)]"

/obj/structure/crewed_lander/freighter/Destroy()
	orbit_freighters -= src
	return ..()

/obj/structure/crewed_lander/freighter/attackby(obj/item/W, mob/user)
	if (launching)
		to_chat(user, SPAN_WARNING("\The [src] is counting down to launch."))
		return
	return ..()

/obj/structure/crewed_lander/freighter/attack_hand(mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || !H.client)
		return
	if (launching)
		to_chat(H, SPAN_WARNING("\The [src] is counting down to launch."))
		return
	var/list/options = list("Launch")
	if (length(hold()))
		options += "Unload hold"
	options += "Cancel"
	var/choice = WWinput(H, "[fuel_kind == "methalox" ? "Methalox" : "Propellant"] [propellant]/[propellant_needed], cargo [length(hold())]/[cargo_max]. Use an item on it to stow it in the hold.", capitalize(name), "Cancel", options)
	if (QDELETED(src) || launching || !H.client || !in_range(src, H) || H.incapacitated())
		return
	switch (choice)
		if ("Launch")
			freight_prompt(H)
		if ("Unload hold")
			unload(H)

/obj/structure/crewed_lander/freighter/vehicle_refusal(destination)
	if (!map || map.ordinal_age < ORBIT_FREIGHT_AGE)
		return "Cargo freighters fly from 2013."
	if (!transfer_bridge.ready() || !(destination in transfer_bridge.peers))
		return "The flight network is down. Try again later."
	return null

// Null when the freighter may be launched by H now, otherwise why not.
/obj/structure/crewed_lander/freighter/proc/freight_refusal(mob/living/human/H)
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = find_pad()
	if (!pad)
		return "\The [src] must stand beside a launch pad."
	var/reason = pad.closed_reason()
	if (reason)
		return reason
	if (propellant < propellant_needed)
		return "\The [src] needs [propellant_needed] units of rocket propellant or methalox ([propellant] loaded)."
	if (!length(hold()))
		return "The cargo hold is empty."
	if (!istype(H) || !H.client || IsGuestKey(H.client.key))
		return "Only players with a BYOND account can launch a freighter."
	if (!party_train_party_of(H))
		return "You have no party to send it for."
	if (persistence_save_active())
		return "The world is saving. Try again in a moment."
	return vehicle_refusal(pad.destination)

/obj/structure/crewed_lander/freighter/proc/freight_prompt(mob/living/human/H)
	var/reason = freight_refusal(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = find_pad()
	var/region = pad.destination
	var/where = space_flight_orbit_ok(region) ? "your party's station at [pad.destination_name()]" : "your party's launch complex at [pad.destination_name()], or its usual arrival point"
	if (WWinput(H, "Launch \the [src] with its hold of [length(hold())] item\s to [where]? The freighter is spent.", "Launch", "Cancel", list("Launch", "Cancel")) != "Launch")
		return
	if (QDELETED(src) || launching || !H.client || !in_range(src, H))
		return
	// The prompt slept: check everything again.
	reason = freight_refusal(H)
	if (!reason && (find_pad() != pad || pad.destination != region))
		reason = "The launch pad changed."
	if (!reason)
		reason = launch_freight(pad, H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))

// Sends the hold to the pad's world for H's party. Returns null once it
// left, or the reason it did not.
// A freight dispatcher (orbit_freight_routes.dm) passes no H, its route's
// party and who set the route up, and never wakes a sleeping world.
/obj/structure/crewed_lander/freighter/proc/launch_freight(obj/structure/region_gate/trail_marker/launch_pad/pad, mob/living/human/H, route_party = null, route_by = null)
	var/destination = pad.destination
	var/party = route_party || party_train_party_of(H)
	if (!party)
		return "You have no party to send it for."
	var/by = route_by || (H && H.client ? H.client.ckey : null)
	// A sleeping world is woken first; that can take a while.
	if (H && shard_group.enabled && shard_group.peers[destination] && shard_group.peers[destination]["state"] != "UP")
		var/woke = shard_group.wake_peer(destination, H)
		if (woke)
			return woke
		if (QDELETED(src) || QDELETED(pad) || pad.destination != destination || !pad.approved || launching)
			return "The launch was called off."
	var/list/cargo = pack_cargo()
	if (!length(cargo))
		return "Nothing in the hold can make the flight."
	var/turf/T = get_turf(src)
	var/payload = orbit_freight_payload(freight_id, party, T, cargo, by)
	if (!orbit_freight_decode(payload))
		return "Something in the hold cannot make the flight. Ask an admin."
	// Hold the freighter while the agent records the flight, so the hold
	// cannot change.
	launching = TRUE
	var/list/result = transfer_bridge.begin_escrow(destination, list(payload), TRUE)
	launching = FALSE
	if (!result)
		return "The flight network is busy. Try again in a moment."
	// Recorded: the freighter and its hold go now, without sleeping.
	for (var/obj/item/I in hold())
		qdel(I)
	visible_message(SPAN_DANGER("\The [src] roars off the pad on a column of fire!"))
	log_game("Cargo freighter: [freight_id] left [T.x],[T.y],[T.z] for [destination] with [length(cargo)] item\s for [party] ([route_party ? "freight route of [by || "nobody"]" : "launched by [by || "nobody"]"]).")
	qdel(src)
	return null

// ---------------------------------------------------------------- payload

/proc/orbit_freight_payload(id, party, turf/T, list/cargo, by)
	var/list/P = list("v" = 1, "kind" = "freight", "id" = id, "party" = party, "from" = shard_group.region, "at" = list(T.x, T.y, T.z), "cargo" = cargo)
	if (by)
		P["by"] = by
	return json_encode(P)

// Returns the decoded freight payload, or null when any field is out of bounds.
/proc/orbit_freight_decode(payload)
	if (!istext(payload) || length(payload) > ORBIT_FREIGHT_PAYLOAD_MAX)
		return null
	var/list/P
	try
		P = json_decode(payload)
	catch
		return null
	if (!islist(P) || P["v"] != 1 || P["kind"] != "freight")
		return null
	for (var/key in P)
		if (!(key in list("v", "kind", "id", "party", "from", "at", "cargo", "by")))
			return null
	if (!istext(P["id"]) || !length(P["id"]) || length(P["id"]) > 64)
		return null
	if (!party_train_valid_party(P["party"]))
		return null
	if (!isnull(P["from"]) && (!istext(P["from"]) || length(P["from"]) > 32))
		return null
	if (!isnull(P["by"]) && (!istext(P["by"]) || length(P["by"]) > 32 || ckey(P["by"]) != P["by"]))
		return null
	var/list/at = P["at"]
	if (!islist(at) || at.len != 3)
		return null
	for (var/v in at)
		if (!isnum(v) || v < 1 || v > 1000 || v != round(v))
			return null
	var/list/cargo = P["cargo"]
	if (!islist(cargo) || !cargo.len || cargo.len > LANDER_CARGO_MAX)
		return null
	for (var/entry in cargo)
		if (!islist(entry))
			return null
		var/list/E = entry
		if (E.len != 2 || !space_cargo_path(E[1], E[2]))
			return null
	return P

// TRUE when every payload of a journal entry or transfer is freight.
/proc/orbit_freight_payloads(list/payloads)
	if (!length(payloads))
		return FALSE
	for (var/payload in payloads)
		if (!istext(payload) || length(payload) > ORBIT_FREIGHT_PAYLOAD_MAX)
			return FALSE
		var/list/P
		try
			P = json_decode(payload)
		catch
			return FALSE
		if (!islist(P) || P["kind"] != "freight")
			return FALSE
	return TRUE

// ---------------------------------------------------------------- arrival

// Where a freight crate lands: beside the party's station hatch in orbit,
// beside its launch complex office elsewhere, else the usual arrival point.
// A refused flight comes back where it left.
/proc/orbit_freight_arrival_turf(list/P, incoming)
	if (!incoming)
		var/list/at = P["at"]
		var/turf/back = locate(at[1], at[2], at[3])
		if (back)
			return back
		return region_travel_arrival_turf()
	if (orbit_world())
		var/obj/structure/region_gate/station_hatch/hatch = orbit_station_hatch(P["party"])
		if (hatch)
			return orbit_freight_beside(get_turf(hatch))
	else
		var/obj/structure/region_gate/launch_complex/office = orbit_project_office_of(P["party"])
		if (office && isturf(office.loc))
			return orbit_freight_beside(get_turf(office))
	return region_travel_arrival_turf()

// A free tile beside T for a crate, so it does not block a hatch or a desk.
/proc/orbit_freight_beside(turf/T)
	if (!T)
		return null
	for (var/turf/N in orange(1, T))
		if (N.density || istype(N, /turf/floor/space))
			continue
		var/blocked = FALSE
		for (var/atom/movable/A in N)
			if (A.density)
				blocked = TRUE
				break
		if (!blocked)
			return N
	return T

// Unpacks recorded freight: arrivals at the destination, or a refused flight
// back at the source. Callers have already recorded the effect, so this never
// refuses; an unreadable payload is reported and dropped.
/proc/orbit_freight_arrive(list/payloads, incoming)
	for (var/payload in payloads)
		var/list/P = orbit_freight_decode(payload)
		if (!P)
			message_admins("Cargo freighter: an unreadable [incoming ? "arriving" : "returned"] freight payload was dropped.")
			continue
		var/turf/T = orbit_freight_arrival_turf(P, incoming)
		if (!T)
			T = locate(1, 1, 1)
		var/obj/structure/closet/crate/C = space_cargo_unpack(P["cargo"], T)
		if (C)
			C.name = incoming ? "freight crate" : "returned freight crate"
			C.desc = "A crate of cargo flown in by an uncrewed freighter for [party_train_party_name(P["party"])]."
			C.visible_message(SPAN_NOTICE(incoming ? "A freight crate drops down on its parachute." : "The freighter's crate comes back: the flight was turned away."))
		log_game("Cargo freighter: [P["id"]] [incoming ? "delivered" : "came back with"] [length(P["cargo"])] item\s for [P["party"]] at [T.x],[T.y],[T.z].")

// A departure replayed after a reload: the save still holds the freighter
// with the hold that flew, so it goes again.
/proc/orbit_freight_replay_departure(list/payloads)
	for (var/payload in payloads)
		var/list/P = orbit_freight_decode(payload)
		if (!P)
			message_admins("Cargo freighter: an unreadable departure could not be replayed.")
			continue
		for (var/obj/structure/crewed_lander/freighter/F in orbit_freighters.Copy())
			if (F.freight_id != P["id"] || QDELETED(F))
				continue
			for (var/obj/item/I in F.hold())
				qdel(I)
			qdel(F)
			log_game("Cargo freighter: replayed [P["id"]]'s departure.")

#undef ORBIT_FREIGHT_AGE
#undef ORBIT_FREIGHT_PROPELLANT
#undef ORBIT_FREIGHT_PAYLOAD_MAX
