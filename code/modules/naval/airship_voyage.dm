// Crewed airship voyages: one character escrow carries the entire deck,
// with the other crew in the same manifest. Nothing is removed before escrow.
#define AIRSHIP_VOYAGE_EDGE 8
#define AIRSHIP_VOYAGE_RECORD_MAX 196608
#define AIRSHIP_VOYAGE_TILE_ENTRIES 30
#define AIRSHIP_VOYAGE_OFFSET 59
#define AIRSHIP_VOYAGE_MAX_CREW 20

/obj/structure/airship_helm/proc/airship_voyage_hull_id()
	if (!voyage_hull_id)
		voyage_hull_id = md5("[shard_group.region]|[world.realtime]|[rand(1, 1000000000)]|[REF(src)]")
	return voyage_hull_id

/proc/airship_voyage_side_close(turf/T, side)
	switch (side)
		if (NORTH) return T.y > world.maxy - AIRSHIP_VOYAGE_EDGE
		if (SOUTH) return T.y <= AIRSHIP_VOYAGE_EDGE
		if (EAST) return T.x > world.maxx - AIRSHIP_VOYAGE_EDGE
		if (WEST) return T.x <= AIRSHIP_VOYAGE_EDGE
	return FALSE

/obj/structure/airship_helm/proc/airship_voyage_near(side = null)
	var/datum/craft_body/built/air/B = body()
	for (var/turf/T in B.cells())
		if (side ? airship_voyage_side_close(T, side) : (airship_voyage_side_close(T, NORTH) || airship_voyage_side_close(T, SOUTH) || airship_voyage_side_close(T, EAST) || airship_voyage_side_close(T, WEST)))
			return TRUE
	return FALSE

/obj/structure/airship_helm/proc/airship_voyage_refusal(mob/living/human/pilot)
	var/datum/craft_body/built/air/B = body()
	if (!istype(B) || !B.placed() || B.landed())
		return "Lift off before setting out."
	if (QDELETED(pilot) || pilot.stat != CONSCIOUS || pilot.restrained() || !B.contains(get_turf(pilot)) || !Adjacent(pilot) || pilot.z != z)
		return "Stand aboard at the helm to set the course."
	if (!craft.anchored || craft.changing_level || craft.turning_to)
		return "Hold position and finish changing course or altitude first."
	if (!airship_voyage_near(air_edge_travel_on() ? B.dir : null))
		return "Fly within [AIRSHIP_VOYAGE_EDGE] tiles of the [air_edge_travel_on() ? "edge ahead" : "edge of the land"] before setting out."
	if (!shard_group.enabled || !transfer_bridge.ready())
		return "No other land can answer just now."
	if (!map || !map.persistence || config.skip_persistence_saving || !shard_group.save_minutes)
		return "This region cannot save a voyage safely."
	if (persistence_admission_blocked())
		return "Wait for the world to finish saving or restoring."
	return B.lift_refusal()

/obj/structure/airship_helm/proc/airship_voyage_route()
	var/datum/craft_body/built/air/B = body()
	var/side = air_edge_side(B.dir)
	var/list/route = air_edge_route(shard_group.region, side, sea_edge_along(side, x, y))
	if (!islist(route))
		return route
	if (route[1] == shard_group.region)
		return "That course leads back to this land."
	return route

/obj/structure/airship_helm/proc/airship_voyage_menu(mob/living/human/pilot)
	if (voyage_pending)
		return
	var/why = airship_voyage_refusal(pilot)
	if (why)
		to_chat(pilot, SPAN_WARNING(why))
		return
	var/id
	var/arrival_side
	var/along
	var/heading
	if (air_edge_travel_on())
		var/list/route = airship_voyage_route()
		if (!islist(route))
			to_chat(pilot, SPAN_WARNING("She cannot set out: [route]."))
			return
		id = route[1]
		arrival_side = text2dir_side(route[2])
		along = route[3]
		var/datum/craft_body/built/air/B = body()
		heading = B.dir
	else
		var/list/options = air_crossing_destinations()
		if (!options.len)
			to_chat(pilot, SPAN_WARNING("No other land can receive a voyage right now."))
			return
		var/choice = WWinput(pilot, "Which land should the airship fly to?", name, "Stay", options + list("Stay"))
		if (QDELETED(src) || !choice || !islist(options[choice]))
			return
		var/list/route = options[choice]
		id = route[1]
		var/list/bearings = continent_sides_toward(id, shard_group.region)
		if (!bearings.len)
			return
		arrival_side = bearings[1]
	var/list/peer = shard_group.peers[id]
	if (!islist(peer) || !(id in transfer_bridge.peers) || shard_group.peer_closed(id) || shard_group.peer_transfers_held(id))
		to_chat(pilot, SPAN_WARNING("There is no open route to that land right now."))
		return
	var/confirmed = WWinput(pilot, "Fly to [peer["name"]] with everyone and everything aboard? The crossing completes after this region's next save. You will arrive holding position over the far coast.", name, "Stay", list("Set out", "Stay"))
	if (confirmed != "Set out" || QDELETED(src) || voyage_pending)
		return
	why = airship_voyage_refusal(pilot)
	if (!why && air_edge_travel_on())
		var/datum/craft_body/built/air/B = body()
		var/list/current = airship_voyage_route()
		if (!islist(current) || current[1] != id || text2dir_side(current[2]) != arrival_side || current[3] != along || B.dir != heading)
			why = "The course changed. Choose the destination again."
	if (why)
		to_chat(pilot, SPAN_WARNING(why))
		return
	voyage_pending = TRUE
	why = airship_voyage_depart(pilot, id, arrival_side, along)
	if (!QDELETED(src))
		voyage_pending = FALSE
	if (why)
		to_chat(pilot, SPAN_WARNING(why))

/obj/structure/airship_helm/proc/airship_voyage_depart(mob/living/human/pilot, id, side, along)
	var/list/peer = shard_group.peers[id]
	if (!islist(peer))
		return "That land is not known here."
	var/datum/craft_body/built/air/B = body()
	var/list/deck = B.cells()
	var/list/crew = list(pilot)
	for (var/turf/T in deck)
		for (var/mob/living/human/H in T)
			crew |= H
	if (crew.len > AIRSHIP_VOYAGE_MAX_CREW)
		return "Too many people are aboard to fly to another land together."
	// Detect unsupported cargo before waking anything. The gate packs again
	// after the wait, so late damage or a changed manifest cannot slip through.
	var/list/check = airship_voyage_pack(crew, side, along)
	if (istext(check))
		return check
	var/datum/travel_hold/hold = travel_hold_begin(crew, peer["name"], list(src), deck, preserve_pull = TRUE)
	. = airship_voyage_depart_held(pilot, id, side, along, crew)
	travel_hold_end(hold)

/obj/structure/airship_helm/proc/airship_voyage_depart_held(mob/living/human/pilot, id, side, along, list/crew)
	if (shard_group.peers[id]["state"] != "UP")
		var/why = shard_group.wake_peer(id, pilot)
		if (why)
			return why
	if (QDELETED(src))
		return "The airship can no longer make the voyage."
	if (!shard_group.poll_peer(id) || shard_group.peers[id]["airship_voyages"] != TRUE)
		return "That land is not ready to receive airships yet."
	if (QDELETED(src))
		return "The airship can no longer make the voyage."
	for (var/mob/living/human/H in crew)
		if (QDELETED(H))
			return "The crew changed. Set out again when everyone is ready."
		if (H.client && !IsGuestKey(H.client.key))
			H.record_persistence_owner()
		else if (!H.client && agent_travel_account(H))
			H.persistence_owner_ckey = agent_travel_account(H)
		else
			return "[H.real_name] must be connected with a BYOND account to make this voyage."
	var/obj/structure/region_gate/airship_voyage/gate = new(get_turf(src))
	gate.destination = id
	gate.helm = src
	gate.pilot = pilot
	gate.arrival_side = side
	gate.along = along
	var/list/result = gate.depart_party(crew)
	qdel(gate)
	var/list/left = result["departed"]
	if (left.len == crew.len)
		return null
	var/list/stayed = result["stayed"]
	for (var/mob/living/human/H in stayed)
		if (stayed[H])
			return "[H.real_name]: [stayed[H]] Nobody left."
	return "The voyage could not start. The airship and everyone aboard stayed here."

/obj/structure/region_gate/airship_voyage
	name = "airship voyage"
	invisibility = 101
	icon = null
	should_save = FALSE
	var/obj/structure/airship_helm/helm
	var/mob/living/human/pilot
	var/arrival_side
	var/along
	var/list/pending
	var/list/packed
	var/flight_id

/obj/structure/region_gate/airship_voyage/accepts_arrivals()
	return FALSE

/obj/structure/region_gate/airship_voyage/attack_hand(mob/living/human/H)
	return

/obj/structure/region_gate/airship_voyage/attack_ghost(mob/user)
	return

/obj/structure/region_gate/airship_voyage/departure_fast_escrow()
	return FALSE

/obj/structure/region_gate/airship_voyage/departure_whole_party()
	return TRUE

/obj/structure/region_gate/airship_voyage/departure_in_place()
	return TRUE

/obj/structure/region_gate/airship_voyage/departure_member_near(mob/living/human/H)
	var/datum/craft_body/built/air/B = QDELETED(helm) ? null : helm.body()
	return !QDELETED(H) && B && isturf(H.loc) && B.contains(H.loc)

/obj/structure/region_gate/airship_voyage/departure_prepare_party(list/ready)
	if (QDELETED(helm))
		return "The airship can no longer make the voyage."
	var/why = helm.airship_voyage_refusal(pilot)
	if (why)
		return why
	var/list/manifest = helm.airship_voyage_pack(ready, arrival_side, along)
	if (istext(manifest))
		return manifest
	flight_id = md5("[helm.airship_voyage_hull_id()]|[world.realtime]|[rand(1, 1000000000)]")
	var/list/record = manifest["record"]
	record["id"] = helm.voyage_hull_id
	packed = manifest["objects"]
	pending = list()
	for (var/mob/living/human/H in ready)
		pending[H] = list("airship_flight" = flight_id, "airship_seat" = list(H.x - helm.x, H.y - helm.y))
	var/list/lead = pending[pilot]
	lead["airship"] = record
	return null

/obj/structure/region_gate/airship_voyage/travel_extra(mob/living/human/H)
	return pending[H]

/obj/structure/region_gate/airship_voyage/departure_party_finished()
	log_game("Airship voyage: [helm] leaves [x],[y],[z] for [destination] with [pending.len] aboard (flight [flight_id]).")
	airship_voyage_remove(helm, packed)

/obj/structure/region_gate/airship_voyage/departure_before_finish(mob/living/human/H, list/leave_behind, turf/origin)
	H.stop_pulling()
	if (H.buckled)
		H.buckled.unbuckle_mob()

// Encode the actual deck rather than a construction sheet (which would refill
// or replace parts). Unsupported objects stop the whole voyage, not just cargo.
/obj/structure/airship_helm/proc/airship_voyage_pack(list/crew, side, along)
	var/datum/craft_body/built/air/B = body()
	if (!B || !B.placed() || x != B.px || y != B.py || z != B.z)
		return "Refit the airship around this helm before setting out."
	var/list/deck = B.cells()
	var/list/found = list()
	var/list/accounts = list()
	var/list/connected_tanks = list()
	var/list/objects = list()
	var/list/tiles = list()
	var/packed_bytes = 0
	for (var/turf/T in deck)
		var/list/entries = list()
		var/obj/covers/airship_deck/floor = null
		for (var/atom/movable/M in T)
			if (M.loc != T || QDELETED(M) || M == src || !M.craft_cargo() || region_travel_ignorable(M))
				continue
			if (ishuman(M))
				var/mob/living/human/H = M
				if (!(H in crew) || H.stat != CONSCIOUS || H.restrained() || H.riding_mob || H.driver_vehicle)
					return "[H.real_name] cannot travel aboard right now."
				var/account = H.client ? ckey(H.client.key) : agent_travel_account(H)
				if (!account || (H.client && IsGuestKey(H.client.key)) || accounts[account])
					return "Everyone aboard must have a different, connected BYOND account."
				accounts[account] = TRUE
				found += H
				continue
			if (istype(M, /obj/covers/airship_deck))
				var/obj/covers/airship_deck/D = M
				if (floor || D.onfire || D.health <= 0)
					return "Repair and put out any fire on the deck before leaving."
				floor = D
				objects += D
				continue
			if (istype(M, /obj/structure/engine))
				var/obj/structure/engine/engine = M
				if (engine.fueltank)
					if (!isturf(engine.fueltank.loc) || connected_tanks[engine.fueltank])
						return "Disconnect any shared or stowed fuel tanks before leaving."
					var/turf/at = engine.fueltank.loc
					for (var/obj/item/weapon/reagent_containers/glass/barrel/barrel in at)
						if (barrel != engine.fueltank && !QDELETED(barrel))
							return "Move the other barrel away from the connected fuel tank before leaving."
					connected_tanks[engine.fueltank] = TRUE
			var/list/E = airship_voyage_pack_object(M, deck)
			if (!E)
				return "Unload or disconnect [M.name] before leaving; it cannot travel aboard."
			// Stop while packing, rather than materialising an oversized deck.
			packed_bytes += length(json_encode(E))
			if (packed_bytes > AIRSHIP_VOYAGE_RECORD_MAX)
				return "There is too much cargo aboard to travel together."
			// Keep the identities of nested cargo as well. If a chest breaks
			// while the agent answers, its previously packed contents must not
			// survive as a second copy on the source deck.
			objects += M
			objects += airship_voyage_contained(M)
			entries += list(E)
			if (entries.len > AIRSHIP_VOYAGE_TILE_ENTRIES)
				return "Too much cargo is stacked on one part of the deck."
		if (!floor)
			return "Part of the deck is missing. Refit it before setting out."
		tiles += list(list(T.x - x, T.y - y, "[floor.type]", floor.dir, floor.health, entries))
	if (found.len != crew.len)
		return "The crew changed. Set out again when everyone is ready."
	var/list/R = list("v" = 1, "id" = voyage_hull_id || md5("airship-voyage-preview"), "name" = craft.name, "dir" = B.dir, "side" = side, "along" = along, "origin" = list(x, y, z), "helm_health" = health, "tiles" = tiles)
	if (!airship_voyage_record_ok(R))
		return "The airship or her cargo is too large or cannot be packed safely."
	return list("record" = R, "objects" = objects)

/proc/airship_voyage_contained(atom/movable/M)
	. = list()
	for (var/atom/movable/C in M.contents)
		if (!QDELETED(C) && !ismob(C) && !region_travel_ignorable(C))
			. += C
			. += airship_voyage_contained(C)

/proc/airship_voyage_pack_object(atom/movable/M, list/deck)
	if (istype(M, /obj/structure/airship_gas_cell))
		var/obj/structure/airship_gas_cell/G = M
		return list("cell", "[G.type]", G.dir, G.health, G.gas, G.gas_amount, G.holes, G.burnt ? 1 : 0)
	if (istype(M, /obj/structure/engine))
		var/obj/structure/engine/E = M
		if (length(E.connections) || E.powersource)
			return null
		if (E.fueltank && (!(E.fueltank.loc in deck) || get_dist(E, E.fueltank) > 1 || !istype(E.fueltank, /obj/item/weapon/reagent_containers/glass/barrel)))
			return null
		var/list/packed = sea_crossing_engine_entry(E)
		return islist(packed) ? packed : null
	if (isitem(M) || sea_crossing_closet_ok(M.type))
		// Use the full saved record rather than the equipment shorthand. A
		// barrel's liquid, a chest's lock and contents and tool wear must ride.
		var/list/R = region_travel_generic_capture(M, root = istype(M, /obj/structure/closet))
		if (R)
			return list("cargo", "item:[json_encode(R)]")
	return null

/proc/airship_voyage_integer(value, low, high)
	return isnum(value) && value >= low && value <= high && value == round(value)

/proc/airship_voyage_health(value)
	return isnum(value) && value > 0 && value <= 1000000

/proc/airship_voyage_key_ok(value)
	if (!istext(value) || length(value) != 32)
		return FALSE
	for (var/i = 1 to 32)
		if (!findtextEx("0123456789abcdef", copytext(value, i, i + 1)))
			return FALSE
	return TRUE

/proc/airship_voyage_offset_ok(list/P)
	return islist(P) && P.len == 2 && airship_voyage_integer(P[1], -AIRSHIP_VOYAGE_OFFSET, AIRSHIP_VOYAGE_OFFSET) && airship_voyage_integer(P[2], -AIRSHIP_VOYAGE_OFFSET, AIRSHIP_VOYAGE_OFFSET)

/proc/airship_voyage_entry_ok(list/E)
	if (!islist(E) || E.len < 2 || !istext(E[2]))
		return FALSE
	switch (E[1])
		if ("cell")
			return E.len == 8 && (text2path(E[2]) in list(/obj/structure/airship_gas_cell, /obj/structure/airship_gas_cell/rubber, /obj/structure/airship_gas_cell/skin)) && (E[3] in alldirs + list(0)) && (isnull(E[4]) || airship_voyage_health(E[4])) && (E[5] in list("helium", "hydrogen", null)) && isnum(E[6]) && E[6] >= 0 && E[6] <= AIR_DRAUGHT_CELL_GAS && (E[5] || !E[6]) && airship_voyage_integer(E[7], 0, 1000000) && (E[8] in list(0, 1))
		if ("e")
			return sea_crossing_engine_valid(E)
		if ("cargo")
			if (E.len != 2)
				return FALSE
			var/list/R = region_travel_generic_record(E[2], TRUE)
			var/path = R ? text2path(R["t"]) : null
			return ispath(path, /obj/item) || sea_crossing_closet_ok(path)
	return FALSE

/proc/airship_voyage_record_ok(list/R)
	if (!islist(R) || R["v"] != 1 || !airship_voyage_key_ok(R["id"]) || !istext(R["name"]) || !length(R["name"]) || length(R["name"]) > 80 || !(R["dir"] in cardinal) || !(R["side"] in cardinal) || (!isnull(R["helm_health"]) && !airship_voyage_health(R["helm_health"])))
		return FALSE
	if (!isnull(R["along"]) && (!isnum(R["along"]) || R["along"] < 0 || R["along"] > 1))
		return FALSE
	var/list/origin = R["origin"]
	if (!islist(origin) || origin.len != 3)
		return FALSE
	for (var/i = 1 to 3)
		if (!airship_voyage_integer(origin[i], 1, 32767))
			return FALSE
	var/list/tiles = R["tiles"]
	if (!islist(tiles) || !tiles.len || tiles.len > AIR_DRAUGHT_MAX_DECK || length(json_encode(R)) > AIRSHIP_VOYAGE_RECORD_MAX)
		return FALSE
	var/list/seen = list()
	for (var/i = 1 to tiles.len)
		var/list/tile = tiles[i]
		if (!islist(tile) || tile.len != 6 || !airship_voyage_offset_ok(list(tile[1], tile[2])) || !istext(tile[3]) || !(text2path(tile[3]) in list(/obj/covers/airship_deck, /obj/covers/airship_deck/aluminium, /obj/covers/airship_deck/steel)) || !(tile[4] in alldirs + list(0)) || !airship_voyage_health(tile[5]))
			return FALSE
		var/key = "[tile[1]],[tile[2]]"
		if (seen[key])
			return FALSE
		seen[key] = tile
		var/list/entries = tile[6]
		if (!islist(entries) || entries.len > AIRSHIP_VOYAGE_TILE_ENTRIES)
			return FALSE
		for (var/j = 1 to entries.len)
			if (!airship_voyage_entry_ok(entries[j]))
				return FALSE
	var/list/queue = list()
	if (!seen["0,0"])
		return FALSE
	queue += list(seen["0,0"])
	seen -= "0,0"
	// A disconnected record could create independent floating planks.
	for (var/i = 1; i <= queue.len; i++)
		var/list/tile = queue[i]
		for (var/d in cardinal)
			var/x = tile[1] + (d == EAST ? 1 : (d == WEST ? -1 : 0))
			var/y = tile[2] + (d == NORTH ? 1 : (d == SOUTH ? -1 : 0))
			var/key = "[x],[y]"
			if (seen[key])
				queue += list(seen[key])
				seen -= key
	return !seen.len

/proc/airship_voyage_payload_ok(list/P)
	if (isnull(P["airship_flight"]))
		return isnull(P["airship"]) && isnull(P["airship_seat"])
	if (!airship_voyage_key_ok(P["airship_flight"]) || !airship_voyage_offset_ok(P["airship_seat"]))
		return FALSE
	// Vehicle records from different modes must not claim the same traveller.
	if (P["voyage"] || P["flight"] || P["lander"] || P["party"] || P["edge"] || P["admin_send"])
		return FALSE
	return isnull(P["airship"]) || airship_voyage_record_ok(P["airship"])

/proc/airship_voyage_remove(obj/structure/airship_helm/helm, list/objects)
	if (!QDELETED(helm))
		helm.decommission()
	for (var/atom/movable/M in objects)
		if (QDELETED(M) || istype(M, /obj/covers/airship_deck))
			continue
		// Some chests and bags drop their contents when deleted.
		airship_voyage_delete_cargo(M)
	for (var/obj/covers/airship_deck/D in objects)
		if (!QDELETED(D))
			qdel(D)
	if (!QDELETED(helm))
		qdel(helm)

/proc/airship_voyage_delete_cargo(atom/movable/M)
	for (var/atom/movable/N in M.contents.Copy())
		if (ismob(N))
			N.forceMove(get_turf(M))
		else
			airship_voyage_delete_cargo(N)
	qdel(M)

// The receiving world reserves the whole footprint, never a lone pivot.
/proc/airship_voyage_clear(list/R, turf/pivot)
	if (!istype(pivot))
		return FALSE
	for (var/list/tile in R["tiles"])
		var/turf/T = locate(pivot.x + tile[1], pivot.y + tile[2], pivot.z)
		if (!air_deck_open(T))
			return FALSE
		for (var/atom/movable/M in T)
			if (!QDELETED(M) && M.loc == T && M.craft_cargo() && !region_travel_ignorable(M))
				return FALSE
	return TRUE

/proc/airship_voyage_anchorage(list/R, incoming)
	var/list/origin = R["origin"]
	if (!incoming)
		var/turf/back = locate(origin[1], origin[2], origin[3])
		if (airship_voyage_clear(R, back))
			return back
	var/side = R["side"]
	if (!incoming)
		// A returned voyage searches the coast where it set out instead.
		var/list/back_sides = list(max(0, world.maxy - origin[2]), max(0, origin[2] - 1), max(0, world.maxx - origin[1]), max(0, origin[1] - 1))
		var/minimum = min(back_sides[1], back_sides[2], back_sides[3], back_sides[4])
		side = back_sides[1] == minimum ? NORTH : (back_sides[2] == minimum ? SOUTH : (back_sides[3] == minimum ? EAST : WEST))
	var/horizontal = side == NORTH || side == SOUTH
	var/length = horizontal ? world.maxx : world.maxy
	var/depth_max = horizontal ? world.maxy : world.maxx
	var/along = incoming ? R["along"] : null
	var/start = isnum(along) ? 1 + round(along * (length - 1)) : clamp(horizontal ? origin[1] : origin[2], 1, length)
	// Search from the lowest eligible flight levels first. Keep the candidate
	// budget bounded on tall maps and prefer a little room from the edge.
	for (var/z = 2, z <= min(world.maxz, 9), z++)
		for (var/pass = 1 to 2)
			var/first = pass == 1 ? min(AIRSHIP_VOYAGE_EDGE, depth_max) : 1
			var/last = pass == 1 ? min(depth_max, AIRSHIP_VOYAGE_OFFSET + 1) : min(depth_max, AIRSHIP_VOYAGE_EDGE - 1)
			for (var/depth = first, depth <= last, depth++)
				for (var/delta = 0, delta <= min(64, length), delta++)
					for (var/sign in list(1, -1))
						if (!delta && sign < 0)
							continue
						var/at = start + delta * sign
						if (at < 1 || at > length)
							continue
						var/turf/T
						switch (side)
							if (NORTH) T = locate(at, world.maxy + 1 - depth, z)
							if (SOUTH) T = locate(at, depth, z)
							if (EAST) T = locate(world.maxx + 1 - depth, at, z)
							if (WEST) T = locate(depth, at, z)
						if (airship_voyage_clear(R, T))
							return T
	return null

/proc/airship_voyage_make_entry(list/E, turf/T)
	if (E[1] == "e")
		return sea_crossing_engine_build(E, T)
	if (E[1] == "cargo")
		return region_travel_make_generic(E[2], T, TRUE)
	var/path = text2path(E[2])
	var/obj/structure/airship_gas_cell/G = new path(T)
	G.dir = E[3]
	G.health = E[4]
	G.gas = E[5]
	G.gas_amount = E[6]
	G.holes = E[7]
	G.burnt = E[8]
	G.update_icon()
	return G

/proc/airship_voyage_build(list/R, turf/pivot, flight)
	if (!airship_voyage_clear(R, pivot))
		return null
	var/list/deck = list()
	var/list/made = list()
	var/list/tanks = list()
	for (var/list/tile in R["tiles"])
		var/turf/T = locate(pivot.x + tile[1], pivot.y + tile[2], pivot.z)
		var/path = text2path(tile[3])
		var/obj/covers/airship_deck/D = new path(T)
		D.afloat = TRUE
		D.dir = tile[4]
		D.health = tile[5]
		D.updateturf()
		made += D
		deck += T
		var/list/entries = tile[6]
		tanks += list(list(tile[1], tile[2], entries))
		for (var/list/E in entries)
			var/atom/movable/M = airship_voyage_make_entry(E, T)
			if (!M)
				for (var/atom/movable/A in made)
					airship_voyage_delete_cargo(A)
				return null
			made += M
	sea_crossing_couple_tanks(list("tiles" = tanks), made, pivot)
	var/obj/structure/airship_helm/helm = new(pivot)
	helm.voyage_hull_id = R["id"]
	helm.voyage_arrived = flight
	helm.dir = R["dir"]
	helm.health = R["helm_health"]
	var/datum/craft_body/built/air/B = new
	B.adopt(deck, pivot, R["dir"])
	B.hull_name = R["name"]
	helm.craft = new /datum/craft/air(B)
	helm.craft.name = B.hull_name
	helm.craft.anchored = TRUE
	helm.craft.fit_drives()
	helm.craft.update_views()
	return helm

/proc/airship_voyage_find(flight)
	for (var/datum/craft/air/C in air_hull_crafts)
		var/datum/craft_body/built/air/B = C.body
		if (!B || !B.placed())
			continue
		var/turf/T = locate(B.px, B.py, B.z)
		var/obj/structure/airship_helm/helm = T ? locate(/obj/structure/airship_helm) in T : null
		if (!QDELETED(helm) && helm.craft == C && helm.voyage_arrived == flight)
			return helm
	return null

/proc/airship_voyage_arrival(list/P, incoming, turf/fallback)
	var/flight = P["airship_flight"]
	if (!flight)
		return null
	var/obj/structure/airship_helm/helm = airship_voyage_find(flight)
	var/list/R = P["airship"]
	if (!helm && islist(R))
		var/turf/at = airship_voyage_anchorage(R, incoming)
		if (at)
			helm = airship_voyage_build(R, at, flight)
		if (helm)
			log_game("Airship voyage: [R["name"]] [incoming ? "arrives" : "returns"] at [at.x],[at.y],[at.z] (flight [flight]).")
		else
			var/obj/structure/airship_recovery/cache = new(fallback)
			cache.airship_record = json_encode(R)
			cache.airship_owner = P["owner"]
			cache.redeploy_incoming = incoming
			message_admins("Airship voyage: no clear sky for [html_encode(R["name"])]. The intact ship and cargo were packed at the arrival point.")
	if (!helm)
		return fallback
	var/datum/craft_body/built/air/B = helm.body()
	var/list/seat = P["airship_seat"]
	var/turf/T = locate(helm.x + seat[1], helm.y + seat[2], helm.z)
	return B.contains(T) ? T : get_turf(helm)

/proc/airship_voyage_arrived(mob/living/human/H, list/P, incoming)
	if (!P["airship_flight"])
		return
	if (airship_voyage_find(P["airship_flight"]))
		to_chat(H, SPAN_NOTICE(incoming ? "The airship holds position over the far coast." : "The voyage was turned back. The airship is holding position here."))
	else
		to_chat(H, SPAN_WARNING("There was not enough clear sky. Your airship and cargo are packed at the arrival point. The pilot can redeploy them."))

// Construction may close the sky while the escrow is committed.
// Keep the exact ship record in a normal world-persisted recovery object rather
// than converting the ship to scrap or dropping parts and losing their state.
/obj/structure/airship_recovery
	name = "packed airship"
	desc = "A voyage could not find room in the sky. The pilot can use this to redeploy the airship and its cargo once there is space."
	icon = 'icons/obj/vehicles/airship_hull.dmi'
	icon_state = "helm_kit"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	crushable = FALSE
	var/airship_record
	var/airship_owner
	var/redeploy_incoming = TRUE

/obj/structure/airship_recovery/ex_act(severity)
	return

/obj/structure/airship_recovery/craft_cargo()
	return FALSE

/obj/structure/airship_recovery/attack_hand(mob/living/human/H)
	if (!istype(H) || !Adjacent(H) || H.z != z || H.stat != CONSCIOUS || H.restrained() || H.buckled || H.riding_mob || travel_hold_input(H))
		return
	var/account = H.client ? ckey(H.client.key) : agent_travel_account(H)
	if (!account || account != airship_owner)
		to_chat(H, SPAN_WARNING("Only the pilot of the voyage can redeploy this airship."))
		return
	var/list/R
	try
		R = json_decode(airship_record)
	catch
		return
	if (!airship_voyage_record_ok(R) || persistence_save_active())
		return
	var/turf/T = airship_voyage_anchorage(R, redeploy_incoming)
	if (!T || !airship_voyage_build(R, T, null))
		to_chat(H, SPAN_WARNING("There is still not enough clear sky for the whole airship."))
		return
	H.forceMove(T)
	qdel(src)
	to_chat(H, SPAN_NOTICE("The airship is back in the sky and holding position."))

#undef AIRSHIP_VOYAGE_EDGE
#undef AIRSHIP_VOYAGE_RECORD_MAX
#undef AIRSHIP_VOYAGE_TILE_ENTRIES
#undef AIRSHIP_VOYAGE_OFFSET
#undef AIRSHIP_VOYAGE_MAX_CREW
