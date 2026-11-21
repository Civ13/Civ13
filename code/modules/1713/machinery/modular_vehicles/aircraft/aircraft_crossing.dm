// ============================================================
// Flying between continents (docs/aircraft-crossing.md)
// ------------------------------------------------------------
// An aircraft in the air near the edge of a continent of the region group can
// fly on to another continent of the shared layout (naval/sea_lanes.dm) that
// has a flight level. The pilot uses Fly to another land on the control
// column; the flight burns fuel for the distance, the plane is packed with the
// bounded vehicle codec (extraction/vehicle_codec.dm, as hangars store it) and
// travels in the pilot's payload, and the crew follow as ordinary region
// travellers (region_travel.dm). The other world builds her in its open sky,
// in from the edge she would have flown in over, still flying the same way,
// and the pilot takes the controls again.
//
// A plane the codec cannot pack (too big, something aboard it cannot carry)
// keeps flying where she is and the pilot is told why. A plane nobody could
// take is built again where she was.
// ============================================================

// Tiles in from the map edge a plane may set off from, and comes in at.
#define AIR_CROSSING_EDGE 8
// Seconds of cruise fuel a tile of the layout costs.
#define AIR_CROSSING_SECONDS_PER_TILE 20
// Deciseconds a plane built from a crossing waits in the air for her pilot.
#define AIR_CROSSING_HOLD 300

var/global/list/air_crossing_planes = list()

/obj/structure/vehicleparts/axis/aircraft
	// The crossing a plane built on arrival came on, so her crew find her.
	var/tmp/air_crossing = null
	// Until this world.time she holds steady in the air: no stall, no step.
	var/tmp/air_crossing_hold = 0
	// The pilot is choosing where to fly: the edge does not stall her meanwhile.
	var/tmp/air_crossing_asking = FALSE

/obj/structure/vehicleparts/axis/aircraft/Destroy()
	air_crossing_planes -= src
	return ..()

// The hidden gate a crossing plane's crew leave by.
/obj/structure/region_gate/air_crossing
	name = "open sky"
	desc = "Open sky beyond the edge of the land."
	invisibility = 101
	icon = null
	var/list/pending = null

/obj/structure/region_gate/air_crossing/accepts_arrivals()
	return FALSE

/obj/structure/region_gate/air_crossing/travel_extra(mob/living/human/H)
	return pending

/obj/structure/region_gate/air_crossing/attack_hand(mob/living/human/user)
	return

/obj/structure/region_gate/air_crossing/attack_ghost(mob/user)
	return

// TRUE when the continent has a standing flight level for planes to arrive in.
/proc/continent_flight(id)
	var/list/place = continent_place(id)
	return place && place.len >= 4 && place[4]

// "Label" = list(region id, tiles) for every continent a plane can fly to now.
/proc/air_crossing_destinations()
	. = list()
	if (!shard_group || !shard_group.enabled || !continent_place(shard_group.region))
		return
	for (var/id in continent_layout)
		if (id == shard_group.region || !continent_flight(id))
			continue
		var/list/peer = shard_group.peers[id]
		if (!islist(peer) || peer["state"] == "STOPPED" || !(peer["state"] == "UP" || shard_group.peer_wakeable(id)))
			continue
		var/tiles = continent_distance(shard_group.region, id)
		.["[peer["name"]], to the [continent_bearing(shard_group.region, id)]: [tiles] tile\s of flying"] = list(id, tiles)

// TRUE when any frame of the plane is within AIR_CROSSING_EDGE of the map edge.
/obj/structure/vehicleparts/axis/aircraft/proc/near_map_edge()
	for (var/obj/structure/vehicleparts/frame/F in frames())
		var/turf/T = get_turf(F)
		if (T && (T.x <= AIR_CROSSING_EDGE || T.y <= AIR_CROSSING_EDGE || T.x > world.maxx - AIR_CROSSING_EDGE || T.y > world.maxy - AIR_CROSSING_EDGE))
			return TRUE
	return FALSE

// Fuel a second of cruise burns now, as burn_flight_fuel() would.
/obj/structure/vehicleparts/axis/aircraft/proc/cruise_fuel_per_second(mob/pilot)
	var/obj/structure/engine/internal/E = engine
	if (!istype(E))
		return 0
	return E.fuelefficiency * 2 * flight_fuel_node_scale(pilot) * load_scale()

// The fuel id in her tank that holds amount, or null.
/obj/structure/vehicleparts/axis/aircraft/proc/fuel_holding(amount)
	var/obj/structure/engine/internal/E = engine
	if (!istype(E) || !E.fueltank || !E.fueltank.reagents)
		return null
	for (var/F in E.fuels)
		if (E.fueltank.reagents.has_reagent(F, amount))
			return F
	return null

// Why she cannot fly to another land now, or null.
/obj/structure/vehicleparts/axis/aircraft/proc/air_crossing_refusal(mob/living/human/pilot)
	if (!airborne())
		return "Take off first."
	if (!pilot || pilot != driver)
		return "Only the pilot can set the course."
	if (!near_map_edge())
		return "Fly out to the edge of the land first, within [AIR_CROSSING_EDGE] tiles of it."
	if (tow_in || tow_out)
		return "Cast off the tow line first."
	if (!transfer_bridge || !transfer_bridge.ready())
		return "No word can be sent across the sea right now."
	if (persistence_save_active())
		return "Wait a moment: the world is being saved."
	return null

/obj/structure/vehicleparts/axis/aircraft/proc/air_crossing_menu(mob/living/human/pilot)
	// Where planes fly over the map edges, the heading picks the land (aircraft_edge.dm).
	if (air_edge_travel_on())
		to_chat(pilot, SPAN_NOTICE("Fly on over the edge of the land: where you come out depends on your heading. Oceans are crossed in one flight if the fuel holds."))
		return
	var/reason = air_crossing_refusal(pilot)
	if (reason)
		to_chat(pilot, SPAN_WARNING(reason))
		return
	var/list/places = air_crossing_destinations()
	if (!places.len)
		to_chat(pilot, SPAN_WARNING("No other land is in reach from here."))
		return
	air_crossing_asking = TRUE
	var/choice = WWinput(pilot, "Fly on to another land with everyone and everything aboard? The flight burns about [AIR_CROSSING_SECONDS_PER_TILE] seconds of cruise fuel for each tile. Everyone aboard makes their home there.", name, "Stay", places + list("Stay"))
	if (!choice || choice == "Stay" || !islist(places[choice]) || QDELETED(src))
		air_crossing_asking = FALSE
		return
	var/list/route = places[choice]
	var/result = air_cross(route[1], route[2], pilot)
	if (!QDELETED(src))
		air_crossing_asking = FALSE
	if (result)
		to_chat(pilot, SPAN_WARNING(result))

// Takes the stopped plane apart into a record. Returns list("record", "transfer"),
// or text when the codec refuses her. Deletes nothing.
/obj/structure/vehicleparts/axis/aircraft/proc/air_crossing_pack()
	// Between steps her next step is already queued; the codec wants her still.
	var/queued = movement_processes
	movement_processes = 0
	. = air_crossing_encode()
	movement_processes = queued

/obj/structure/vehicleparts/axis/aircraft/proc/air_crossing_encode()
	var/list/flags = list()
	for (var/obj/O in vehicle_storage_objects(components | transporting))
		flags[O] = O.should_save
	var/datum/extraction_vehicle_codec/codec = new
	codec.ignore_ground = TRUE
	var/list/record = codec.encode(src)
	var/datum/extraction_vehicle_transfer/transfer = new
	transfer.ignore_ground = TRUE
	if (!record || !transfer.capture(src, TRUE))
		for (var/obj/O in flags)
			if (!QDELETED(O))
				O.should_save = flags[O]
		var/why = codec.last_error ? codec.last_error : transfer.last_error
		return "She cannot make the flight[why ? ": [why]" : ""]. Only a plane that fits a hangar, with nothing loose aboard but what is stowed in her hold, can fly that far."
	return list("record" = record, "transfer" = transfer)

// Gear, engine and course back as they were, with pilot at the controls.
/obj/structure/vehicleparts/axis/aircraft/proc/air_crossing_resume(gear, mob/living/human/pilot)
	if (engine)
		engine.on = TRUE
		engine.update_icon()
	if (istype(pilot) && wheel && wheel.drivingchair && !QDELETED(pilot))
		pilot.forceMove(get_turf(wheel.drivingchair))
		wheel.drivingchair.buckle_mob(pilot)
	add_transporting(FALSE)
	currentspeed = max(stall_gear, gear)
	vehicle_m_delay = get_speed()
	moving = TRUE
	stall_seconds = 0
	edge_blocked = FALSE
	lastmovementloop = 0
	startmovementloop()

// Flies her to region id, tiles away. Null when she left, else why not. Sleeps.
/obj/structure/vehicleparts/axis/aircraft/proc/air_cross(id, tiles, mob/living/human/pilot)
	var/reason = air_crossing_refusal(pilot)
	if (reason)
		return reason
	var/need = round(cruise_fuel_per_second(pilot) * AIR_CROSSING_SECONDS_PER_TILE * tiles, 0.1)
	var/fuel = fuel_holding(need)
	if (!fuel)
		return "She has too little fuel to reach that land: the flight needs about [need] units."
	var/list/peer = shard_group.peers[id]
	if (!peer)
		return "That land is not known here."
	if (shard_group.peer_transfers_held(id))
		return "No aircraft can land there for now: that land is closed to arrivals. Ask an admin."
	if (peer["state"] != "UP")
		var/woke = shard_group.wake_peer(id, pilot)
		if (woke)
			return woke
		if (QDELETED(src))
			return "The flight was called off."
		reason = air_crossing_refusal(pilot)
		if (reason)
			return reason
	// The control column goes back in its seat: it is part of her, not the pilot's kit.
	stow_column(pilot)
	. = air_cross_crew(id, tiles, pilot, need, fuel)
	if (. && !QDELETED(src) && !QDELETED(pilot) && wheel && wheel.loc == wheel.drivingchair && pilot.buckled == wheel.drivingchair)
		pilot.put_in_active_hand(wheel)

/obj/structure/vehicleparts/axis/aircraft/proc/stow_column(mob/living/human/pilot)
	if (wheel && wheel.drivingchair && wheel.loc == pilot)
		pilot.remove_from_mob(wheel)
		wheel.forceMove(wheel.drivingchair)

// The rest of air_cross(), once the column is stowed.
/obj/structure/vehicleparts/axis/aircraft/proc/air_cross_crew(id, tiles, mob/living/human/pilot, need, fuel)
	var/list/crew = list()
	for (var/mob/living/M in transporting)
		if (!ishuman(M))
			return "She cannot fly that far with [M] aboard."
		var/mob/living/human/H = M
		var/problem = null
		if (H.client ? IsGuestKey(H.client.key) : !agent_travel_account(H))
			problem = "only players with a BYOND account can make the flight"
		else if (H.stat != CONSCIOUS || H.restrained())
			problem = "[H.real_name] cannot make the flight like this"
		else
			var/list/items = H.region_travel_items()
			if (istext(items))
				problem = "[H.real_name]: [items]"
		if (problem)
			return "She cannot fly on: [problem]."
		crew += H
	// The pilot carries her and so lands first.
	crew -= pilot
	crew.Insert(1, pilot)
	var/flight = "[ckey(shard_group.region) || "world"]-[num2text(world.realtime, 20)]-[rand(1000, 9999)]"
	var/gear = currentspeed
	var/state = flight_state
	var/turf/pivot = get_turf(src)
	var/obj/structure/region_gate/air_crossing/gate = new(pivot)
	gate.destination = id
	// Everyone waits in the gate while she is packed, so nothing aboard counts twice.
	moving = FALSE
	currentspeed = 0
	air_crossing_hold = world.time + AIR_CROSSING_HOLD
	for (var/mob/living/human/H in crew)
		H.stop_pulling()
		if (H.buckled)
			H.buckled.unbuckle_mob()
		if (H.client)
			H.record_persistence_owner()
		else
			H.persistence_owner_ckey = agent_travel_account(H)
		H.forceMove(gate)
	driver = null
	if (engine)
		engine.on = FALSE
	transporting -= crew
	var/list/packed = air_crossing_pack()
	if (istext(packed))
		air_crossing_hold = 0
		air_crossing_resume(gear, pilot)
		for (var/mob/living/human/H in crew - pilot)
			H.forceMove(pivot)
		qdel(gate)
		return packed
	var/list/record = packed["record"]
	var/datum/extraction_vehicle_transfer/transfer = packed["transfer"]
	var/list/plane = list("v" = 1, "record" = record, "name" = name, "dir" = dir, "gear" = gear, "state" = state, "from" = list(pivot.x, pivot.y, pivot.z))
	// Flown off an edge (aircraft_edge.dm): she comes in where her line reaches.
	if (isnum(air_edge_along))
		plane["along"] = air_edge_along
	burn_crossing_fuel(fuel, need)
	log_game("Air crossing: [key_name(pilot)] flies [name] ([crew.len] aboard) from [pivot.x],[pivot.y],[pivot.z] to [id] (flight [flight], [need] fuel).")
	// She leaves the sky before anyone goes, so nothing aboard can be taken twice.
	for (var/obj/item/I in transfer.cargo)
		qdel(I)
	for (var/obj/O in transfer.parts - transfer.cargo)
		for (var/obj/child in O.contents.Copy())
			if (!istype(child, /atom/movable/lighting_overlay))
				qdel(child)
		if (istype(O, /obj/structure/vehicleparts/frame))
			O:broken = TRUE
		if (O != src)
			qdel(O)
	var/carried = FALSE
	var/list/stayed = list()
	for (var/mob/living/human/H in crew)
		if (QDELETED(H) || H.loc != gate)
			continue
		gate.pending = list("flight" = flight)
		if (H == pilot)
			gate.pending["pilot"] = 1
		if (!carried)
			gate.pending["plane"] = plane
		var/result = gate.depart(H)
		if (result == "departed")
			carried = TRUE
		else
			stayed += H
			to_chat(H, SPAN_WARNING("You stay behind: [result]"))
	gate.pending = null
	if (!carried)
		var/obj/structure/vehicleparts/axis/aircraft/again = air_crossing_build(plane, pivot, null)
		for (var/mob/living/human/H in stayed)
			H.forceMove(pivot)
		if (again)
			again.air_crossing_hold = 0
			again.air_crossing_resume(gear, (pilot in stayed) ? pilot : null)
		qdel(gate)
		qdel(src)
		return "Nobody could make the flight."
	// She has gone; whoever could not follow comes down at the nearest arrival point.
	var/turf/ashore = region_travel_arrival_turf() || pivot
	for (var/mob/living/human/H in stayed)
		H.forceMove(ashore)
		to_chat(H, SPAN_WARNING("[plane["name"]] flew on without you. You are set down here."))
	qdel(gate)
	qdel(src)
	return null

/obj/structure/vehicleparts/axis/aircraft/proc/burn_crossing_fuel(fuel, amount)
	var/obj/structure/engine/internal/E = engine
	if (istype(E) && E.fueltank && E.fueltank.reagents)
		E.fueltank.reagents.remove_reagent(fuel, amount)

// ---------------------------------------------------------------- arriving

// The open-air level planes fly on here: the lowest level of open sky with
// ground under it, or null.
/proc/air_crossing_flight_z()
	// A few points, so a building standing at one of them does not hide the level.
	for (var/z = 2, z <= world.maxz, z++)
		for (var/list/at in list(list(0.5, 0.5), list(0.1, 0.1), list(0.9, 0.9), list(0.1, 0.9), list(0.9, 0.1)))
			var/turf/T = locate(max(1, round(world.maxx * at[1])), max(1, round(world.maxy * at[2])), z)
			if (istype(T, /turf/sky/building))
				return z
	return null

// TRUE when a well formed plane record of a payload.
/proc/air_crossing_plane_ok(list/plane)
	if (!islist(plane) || plane["v"] != 1 || !islist(plane["record"]) || !istext(plane["name"]) || length(plane["name"]) > 80)
		return FALSE
	if (!(plane["dir"] in cardinal) || !isnum(plane["gear"]) || plane["gear"] < 0 || plane["gear"] > 10)
		return FALSE
	if (!(plane["state"] in list(AIRCRAFT_LOW, AIRCRAFT_CRUISE)))
		return FALSE
	if (!isnull(plane["along"]) && (!isnum(plane["along"]) || plane["along"] < 0 || plane["along"] > 1))
		return FALSE
	var/list/from = plane["from"]
	if (!islist(from) || from.len != 3)
		return FALSE
	for (var/v in from)
		if (!isnum(v) || v < 1 || v > 2000 || v != round(v))
			return FALSE
	var/datum/extraction_vehicle_codec/codec = new
	return codec.validate(plane["record"])

/proc/air_crossing_payload_ok(list/P)
	if (isnull(P["flight"]))
		return isnull(P["plane"]) && isnull(P["pilot"])
	if (!istext(P["flight"]) || !length(P["flight"]) || length(P["flight"]) > 64)
		return FALSE
	if (!isnull(P["pilot"]) && P["pilot"] != 1)
		return FALSE
	return isnull(P["plane"]) || air_crossing_plane_ok(P["plane"])

/proc/air_crossing_find(flight)
	for (var/obj/structure/vehicleparts/axis/aircraft/A in air_crossing_planes.Copy())
		if (QDELETED(A))
			air_crossing_planes -= A
		else if (A.air_crossing == flight)
			return A
	return null

// Builds the plane of a payload at pivot (her axis), flying, holding for her
// pilot. Returns the aircraft, or null.
/proc/air_crossing_build(list/plane, turf/pivot, flight)
	if (!istype(pivot))
		return null
	var/datum/extraction_vehicle_codec/codec = new
	codec.ignore_ground = TRUE
	codec.allow_sky = TRUE
	var/obj/structure/vehicleparts/axis/aircraft/A = codec.decode(plane["record"], pivot)
	if (!istype(A))
		if (A)
			qdel(A)
		return null
	var/datum/extraction_vehicle_transfer/transfer = new
	transfer.ignore_ground = TRUE
	if (transfer.capture(A, TRUE))
		for (var/obj/O in vehicle_storage_objects(transfer.parts))
			O.should_save = initial(O.should_save)
	A.should_save = initial(A.should_save)
	A.add_transporting(FALSE)
	A.air_crossing = flight
	A.air_crossing_hold = world.time + AIR_CROSSING_HOLD
	A.set_flight_state(plane["state"])
	if (flight)
		air_crossing_planes |= A
	return A

// Where her pivot goes: in from the edge she flies in over (the side behind her
// heading), along it at the nearest clear spot to where she left the other map.
/proc/air_crossing_anchorage(list/plane)
	var/z = air_crossing_flight_z()
	if (!z)
		return null
	var/list/from = plane["from"]
	var/side = turn(plane["dir"], 180)
	var/along_max = (side == NORTH || side == SOUTH) ? world.maxx : world.maxy
	var/along = (side == NORTH || side == SOUTH) ? from[1] : from[2]
	if (isnum(plane["along"]))
		along = 1 + round(plane["along"] * (along_max - 1))
	along = clamp(along, AIR_CROSSING_EDGE, along_max - AIR_CROSSING_EDGE)
	var/depth = AIR_CROSSING_EDGE
	for (var/offset = 0, offset <= along_max, offset += 3)
		for (var/sign in list(1, -1))
			var/a = along + offset * sign
			if (a < AIR_CROSSING_EDGE || a > along_max - AIR_CROSSING_EDGE)
				continue
			var/turf/T
			switch (side)
				if (NORTH) T = locate(a, world.maxy - depth, z)
				if (SOUTH) T = locate(a, 1 + depth, z)
				if (EAST) T = locate(world.maxx - depth, a, z)
				else T = locate(1 + depth, a, z)
			if (T && air_crossing_clear(plane["record"], T))
				return T
	return null

// TRUE when every root part of the record would stand on empty open sky.
/proc/air_crossing_clear(list/record, turf/pivot)
	for (var/list/N in record["nodes"])
		if (N["parent"])
			continue
		var/turf/T = locate(pivot.x + N["dx"], pivot.y + N["dy"], pivot.z)
		if (!istype(T, /turf/sky/building))
			return FALSE
		for (var/atom/movable/O in T)
			if (!istype(O, /atom/movable/lighting_overlay))
				return FALSE
	return TRUE

// Where an arriving (or refused) crew member of a flight appears.
/proc/air_crossing_arrival_turf(list/P, incoming)
	if (!islist(P) || !istext(P["flight"]))
		return null
	var/obj/structure/vehicleparts/axis/aircraft/A = air_crossing_find(P["flight"])
	if (!A && islist(P["plane"]))
		var/list/plane = P["plane"]
		var/turf/pivot = null
		if (!incoming)
			var/list/from = plane["from"]
			var/turf/back = locate(from[1], from[2], from[3])
			if (back && air_crossing_clear(plane["record"], back))
				pivot = back
		if (!pivot)
			pivot = air_crossing_anchorage(plane)
		if (pivot)
			A = air_crossing_build(plane, pivot, P["flight"])
		if (A)
			log_game("Air crossing: [plane["name"]] [incoming ? "flew in" : "came back"] at [pivot.x],[pivot.y],[pivot.z] (flight [P["flight"]]).")
		else
			message_admins("Air crossing: no clear sky for [html_encode(plane["name"])]; she was lost and her crew set down on the ground.")
			log_game("Air crossing: no clear sky for [plane["name"]] (flight [P["flight"]]).")
			return null
	if (!A)
		return null
	var/list/frames = A.frames()
	return frames.len ? get_turf(pick(frames)) : get_turf(A)

// Seats the crew member: the pilot takes the controls and she flies on.
/proc/air_crossing_arrived(mob/living/human/H, list/P, incoming)
	if (!istype(H) || !islist(P) || !istext(P["flight"]))
		return
	var/obj/structure/vehicleparts/axis/aircraft/A = air_crossing_find(P["flight"])
	if (!A || get_dist(H, A) > 6)
		to_chat(H, SPAN_WARNING("There was no clear sky to bring the plane in. You were set down here."))
		return
	A.add_transporting(FALSE)
	// The pilot carries her and takes the controls; if the pilot could not
	// come, whoever brought her does.
	if ((P["pilot"] || islist(P["plane"])) && !A.driver)
		var/list/plane = P["plane"]
		A.air_crossing_hold = 0
		A.air_crossing_resume(islist(plane) ? plane["gear"] : A.stall_gear, H)
		to_chat(H, SPAN_NOTICE(incoming ? "Land comes into sight below. You have the controls." : "The flight was turned back. You are over the place you set out from, and you have the controls."))
	else
		to_chat(H, SPAN_NOTICE(incoming ? "Land comes into sight below." : "The flight was turned back."))

#undef AIR_CROSSING_EDGE
#undef AIR_CROSSING_SECONDS_PER_TILE
#undef AIR_CROSSING_HOLD
