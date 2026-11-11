// Physical train routes. Peer advertisements aid discovery only; destination
// admission always revalidates its actual station and track.
#define TRAIN_ROUTE_STATIONS_MAX 128
#define TRAIN_ROUTE_SEGMENTS_MAX 64

/obj/structure/region_gate/var/train_station_id = null
/obj/structure/trains/var/list/train_route = null

/proc/train_route_valid_id(id)
	if(!istext(id) || length(id) != 32) return FALSE
	for(var/i = 1, i <= 32, i++)
		if(!findtext("0123456789abcdef", copytext(id, i, i + 1))) return FALSE
	return TRUE

/obj/structure/region_gate/proc/physical_station_id()
	if(!train_station_id)
		train_station_id = md5("[shard_group.group]:[shard_group.region]:[world.realtime]:[rand(1,1000000000)]:\ref[src]")
	return train_station_id

// Only completed player offices or already-owned Rail Yard berths qualify.
// This does not allocate/reassign a berth or change the stationary train home.
/obj/structure/region_gate/proc/train_endpoint_party()
	return null

/obj/structure/region_gate/proc/train_endpoint_ready()
	return FALSE

/obj/structure/region_gate/proc/train_endpoint_range()
	return 2

/obj/structure/region_gate/railway_station/train_endpoint_party()
	return party

/obj/structure/region_gate/railway_station/train_endpoint_ready()
	return completed && party_train_valid_party(party) && !station_problem()

/obj/structure/region_gate/rail_berth/train_endpoint_party()
	return party

/obj/structure/region_gate/rail_berth/train_endpoint_range()
	// Generated berths stand south of their static home and running line.
	return 7

/obj/structure/region_gate/rail_berth/train_endpoint_ready()
	if(!shard_group.enabled || shard_group.kind != "RAILYARD" || berth < 1 || !party_train_valid_party(party)) return FALSE
	var/list/network = train_route_network(src)
	for(var/turf/T in network)
		if(train_route_inward(T)) return TRUE
	return FALSE

/proc/train_route_station(id, party)
	if(!train_route_valid_id(id) || !party_train_valid_party(party)) return null
	for(var/obj/structure/region_gate/S in region_gates)
		if(!QDELETED(S) && S.train_station_id == id && S.train_endpoint_party() == party && S.train_endpoint_ready())
			return S
	return null

/proc/train_route_revision(obj/structure/region_gate/S)
	var/list/network = train_route_network(S)
	if(!islist(network) || !network.len) return null
	var/list/records = list("[S.physical_station_id()]:[S.train_endpoint_party()]:[S.x],[S.y],[S.z]")
	for(var/turf/T in network)
		for(var/obj/structure/rails/R in T)
			records += "[T.x],[T.y],[T.z]:[R.type]:[R.dir]:[R.switched]:[R.turn_dir]:[R.sw_direction]"
	return md5(json_encode(sortList(records)))

/proc/train_route_advertisements()
	var/list/result = list()
	if(!shard_group.enabled) return result
	for(var/obj/structure/region_gate/S in region_gates)
		if(result.len >= TRAIN_ROUTE_STATIONS_MAX) break
		if(!QDELETED(S) && S.train_endpoint_ready())
			result += list(list("id" = S.physical_station_id(), "party" = S.train_endpoint_party(), "name" = copytext(S.name, 1, 65), "revision" = train_route_revision(S)))
	return result

/proc/train_route_clean_advertisements(list/records)
	var/list/result = list()
	if(!islist(records) || records.len > TRAIN_ROUTE_STATIONS_MAX) return result
	var/list/seen = list()
	for(var/list/entry in records)
		var/id = entry["id"]
		if(!train_route_valid_id(id) || seen[id] || !party_train_valid_party(entry["party"]) || !train_route_valid_id(entry["revision"])) continue
		seen[id] = TRUE
		result += list(list("id" = id, "party" = entry["party"], "revision" = entry["revision"], "name" = istext(entry["name"]) ? copytext(entry["name"], 1, 65) : "Railway station"))
	return result

// Reachable rails, bounded; an overflow never returns a partial network.
/proc/train_route_network(obj/structure/region_gate/S)
	var/list/pending = list()
	var/list/seen = list()
	// seen marks a turf when it is queued, so the queue never rescans itself.
	for(var/turf/T in range(S.train_endpoint_range(), S))
		if(rail_at(T) && !seen[T])
			seen[T] = TRUE
			pending += T
	var/index = 1
	while(index <= pending.len)
		if(pending.len > 50000) return null
		var/turf/T = pending[index++]
		for(var/d in cardinal)
			var/turf/N = get_step(T, d)
			if(N && !seen[N] && rail_at(N))
				seen[N] = TRUE
				pending += N
	return seen

/proc/train_route_inward(turf/T)
	if(!T) return 0
	// Corners cannot provide the three-wide footprint.
	if(T.x == 1 && T.y > 1 && T.y < world.maxy) return EAST
	if(T.x == world.maxx && T.y > 1 && T.y < world.maxy) return WEST
	if(T.y == 1 && T.x > 1 && T.x < world.maxx) return NORTH
	if(T.y == world.maxy && T.x > 1 && T.x < world.maxx) return SOUTH
	return 0

// Initial arrivals support straight ordinary rail only, not a switch/turn whose
// routing would disagree with the staged consist's inward heading.
/proc/train_route_straight_rail(turf/T, heading)
	var/found = 0
	for(var/obj/structure/rails/R in T)
		if(!istype(R, /obj/structure/rails/regular)) return FALSE
		if(R.dir != heading && R.dir != turn(heading, 180)) return FALSE
		found++
	return found == 1

// Head-to-tail centres wholly inside the map. Caller must reserve this exact
// footprint atomically and recheck it immediately before materialization.
/proc/train_route_arrival_centres(station_id, party, count, expected_revision = null)
	if(!isnum(count) || count != round(count) || count < 1 || count > TRAIN_ROUTE_SEGMENTS_MAX) return null
	var/obj/structure/region_gate/S = train_route_station(station_id, party)
	if(!S || (expected_revision && expected_revision != train_route_revision(S))) return null
	var/list/network = train_route_network(S)
	if(!islist(network)) return null
	for(var/turf/edge in network)
		var/heading = train_route_inward(edge)
		if(!heading) continue
		var/list/centres = list()
		var/turf/T = edge
		var/clear = TRUE
		for(var/i = 1, i <= count, i++)
			if(!T || !network[T] || !train_route_straight_rail(T, heading))
				clear = FALSE
				break
			var/turf/left = get_step(T, turn(heading, 90))
			var/turf/right = get_step(T, turn(heading, -90))
			if(!left || !right)
				clear = FALSE
				break
			var/list/deck = list(T, left, right)
			for(var/turf/D in deck)
				if(D.density)
					clear = FALSE
				for(var/atom/movable/A in D)
					if(isliving(A) || istype(A, /obj/structure/trains) || istype(A, /obj/structure/train_part) || (A.density && !istype(A, /obj/structure/rails)))
						clear = FALSE
			if(deck.len != 3 || !clear) break
			centres.Insert(1, T)
			T = get_step(T, heading)
		if(clear && centres.len == count)
			return list("centres" = centres, "heading" = heading)
	return null

/proc/train_route_link_allowed(destination)
	if(!shard_group.enabled || !istext(destination) || !(destination in shard_group.peers) || !(destination in transfer_bridge.peers)) return FALSE
	var/list/peer = shard_group.peers[destination]
	// The first implementation connects outpost stations through the hub.
	return shard_group.kind == "RAILYARD" || peer["kind"] == "RAILYARD"

/proc/train_route_departure_problem(obj/structure/trains/head, turf/edge)
	if(!head || !islist(head.train_route)) return "Select a destination at a railway office first."
	var/list/route = head.train_route
	if(!train_route_link_allowed(route["destination"])) return "This railway route is no longer enrolled."
	var/obj/structure/region_gate/S = train_route_station(route["source_station"], route["party"])
	if(!S) return "The departure station is missing or its track is broken."
	if(route["source_revision"] != train_route_revision(S)) return "The departure track changed. Select the route again."
	var/list/network = train_route_network(S)
	if(!islist(network) || !edge || !network[edge] || !train_route_inward(edge) || head.dir != turn(train_route_inward(edge), 180))
		return "The train must face outward on its station's map-edge track."
	if(!train_route_valid_id(route["station"])) return "The destination station is invalid."
	return null

/obj/structure/region_gate/proc/train_route_menu(mob/living/human/H)
	var/party = train_endpoint_party()
	if(!H || !H.client || QDELETED(src) || !Adjacent(H) || !train_endpoint_ready() || !party_train_may_board(H, party)) return
	var/list/engines = list()
	for(var/obj/structure/trains/locomotive/L in range(train_endpoint_range(), src))
		if(!L.automovement && !L.train_transfer_busy)
			engines["[L.name] ([L.x],[L.y])"] = L
	if(!engines.len)
		to_chat(H, SPAN_WARNING("Park a locomotive within two tiles of this office first."))
		return
	var/list/destinations = list()
	for(var/region in shard_group.peers)
		if(!train_route_link_allowed(region)) continue
		var/list/peer = shard_group.peers[region]
		for(var/list/entry in peer["train_stations"])
			if(entry["party"] == party)
				destinations["[peer["name"]]: [entry["name"]] ([entry["id"]])"] = list("destination" = region, "station" = entry["id"], "destination_revision" = entry["revision"])
	if(!destinations.len)
		to_chat(H, SPAN_WARNING("No established railway station for your party is known at the other end. Build its office and edge-connected rails first, and let the regions refresh."))
		return
	var/engine_choice = WWinput(H, "Choose the stopped locomotive.", "Railway destination", null, engines + list("Cancel"))
	var/obj/structure/trains/locomotive/L = engines[engine_choice]
	if(!L) return
	var/choice = WWinput(H, "Choose an established station.", "Railway destination", null, destinations + list("Cancel"))
	var/list/route = destinations[choice]
	// Both prompts sleep; ownership, proximity and track are revalidated.
	if(!route || QDELETED(src) || QDELETED(L) || !H.client || !Adjacent(H) || !train_endpoint_ready() || train_endpoint_party() != party || !party_train_may_board(H, party)) return
	if(get_dist(src, L) > train_endpoint_range() || L.z != z || L.automovement || L.train_transfer_busy || !train_route_link_allowed(route["destination"])) return
	L.train_route = list("source_station" = physical_station_id(), "destination" = route["destination"], "station" = route["station"], "party" = party, "source_revision" = train_route_revision(src), "destination_revision" = route["destination_revision"])
	to_chat(H, SPAN_NOTICE("Route planned. Physical departures remain unavailable pending safe transfer integration; this does not move your train or passengers."))

// Available at an assigned berth without replacing its existing travel/home UI.
/obj/structure/region_gate/verb/plan_physical_train_route()
	set name = "Plan train route"
	set category = null
	set src in oview(1)
	if(istype(usr, /mob/living/human))
		train_route_menu(usr)

#undef TRAIN_ROUTE_STATIONS_MAX
#undef TRAIN_ROUTE_SEGMENTS_MAX
