// ============================================================
// Ships over linked map edges (docs/ocean-regions.md)
// ------------------------------------------------------------
// In the earth group every sea edge leads to another land or ocean (the world
// links table, docs/world-links.md: world_sea_links). A commissioned ship
// lying off such an edge can sail on over it: her tiller offers "Sail over
// the horizon", and she crosses with her whole crew and cargo as one party
// (ship_crossing.dm cross(), region_travel.dm depart_party()). She comes out
// on the facing edge at the matching place along it, as far along that edge's
// stretch as she left along hers.
//
// Gaia and Greenland are islands set inside the Atlantic (world_insets): a
// ship off any of their edges comes out beside that side of the island's box
// of breakers in the Atlantic, and a ship in the Atlantic that lies against
// the box comes out on the island's edge on that side.
//
// Only a seaworthy ship crosses (a mast or a running engine, and two crew).
// Swimmers and small boats do not: walkers use the walk links (region_edge.dm)
// and the sea edges hold nobody in the water. The whole thing waits for the
// host's group option edge_travel_oceans (shard_group.dm).
// ============================================================

#define SEA_EDGE_BAND 4
#define SEA_EDGE_MIN_CREW 2
// How far along the arrival edge she may be put from the matching place.
#define SEA_EDGE_SEARCH 80
// How far in from the edge (or out from a box) she may be put.
#define SEA_EDGE_DEPTH 40

// TRUE when ships in this world sail over linked map edges.
/proc/sea_edge_travel_on()
	return shard_group && shard_group.enabled && shard_group.edge_travel_oceans && istext(shard_group.region)

// The ocean a land is set inside, or null.
/proc/sea_edge_inset_ocean(land)
	for (var/ocean in world_insets)
		var/list/boxes = world_insets[ocean]
		if (islist(boxes) && islist(boxes[land]))
			return ocean
	return null

// The fraction along a side of the map that x or y is: 0 at the west or
// south end, 1 at the east or north end.
/proc/sea_edge_along(side, x, y)
	if (side == "north" || side == "south")
		return world.maxx > 1 ? clamp((x - 1) / (world.maxx - 1), 0, 1) : 0
	return world.maxy > 1 ? clamp((y - 1) / (world.maxy - 1), 0, 1) : 0

// list(min x, min y, max x, max y) of her deck, or null.
/datum/craft_body/built/proc/sea_edge_bounds()
	var/list/B = null
	for (var/turf/T in cells())
		if (!B)
			B = list(T.x, T.y, T.x, T.y)
			continue
		B[1] = min(B[1], T.x)
		B[2] = min(B[2], T.y)
		B[3] = max(B[3], T.x)
		B[4] = max(B[4], T.y)
	return B

// Where sailing on from here leads, or null: list(region, arrival side,
// fraction along the arrival stretch).
/datum/craft_body/built/proc/sea_edge_link()
	if (!sea_edge_travel_on())
		return null
	var/list/B = sea_edge_bounds()
	if (!B)
		return null
	return sea_edge_link_at(shard_group.region, B)

// The pure part of sea_edge_link(), for a hull with bounds B in region here.
/proc/sea_edge_link_at(here, list/B)
	var/cx = (B[1] + B[3]) / 2
	var/cy = (B[2] + B[4]) / 2
	// In an ocean: against an island's box of breakers.
	var/list/boxes = world_insets[here]
	if (islist(boxes))
		for (var/land in boxes)
			var/list/X = boxes[land]
			if (B[1] > X[3] + 1 || B[3] < X[1] - 1 || B[2] > X[4] + 1 || B[4] < X[2] - 1)
				continue
			// The side of the box she lies against: where her middle is furthest out.
			var/dx = (cx - (X[1] + X[3]) / 2) / max(1, (X[3] - X[1]) / 2)
			var/dy = (cy - (X[2] + X[4]) / 2) / max(1, (X[4] - X[2]) / 2)
			if (abs(dx) >= abs(dy))
				return list(land, dx < 0 ? "west" : "east", clamp((cy - X[2]) / max(1, X[4] - X[2]), 0, 1))
			return list(land, dy < 0 ? "south" : "north", clamp((cx - X[1]) / max(1, X[3] - X[1]), 0, 1))
	for (var/side in list("north", "south", "east", "west"))
		var/near = FALSE
		switch (side)
			if ("north") near = B[4] > world.maxy - SEA_EDGE_BAND
			if ("south") near = B[2] <= SEA_EDGE_BAND
			if ("east") near = B[3] > world.maxx - SEA_EDGE_BAND
			if ("west") near = B[1] <= SEA_EDGE_BAND
		if (!near)
			continue
		var/f = sea_edge_along(side, cx, cy)
		// An ocean whose west and east edges join (the Arctic, the Southern
		// Ocean): she sails on round the world into its other side.
		var/list/O = world_oceans[here]
		if ((side == "west" || side == "east") && islist(O) && O.len >= 6 && islist(O[6]) && (("west" in O[6]) || ("east" in O[6])))
			return list(here, region_edge_opposite(side), f)
		// An island land: every edge leads into its ocean, beside that side of its box.
		var/ocean = sea_edge_inset_ocean(here)
		if (ocean)
			return list(ocean, side, f)
		var/list/sides = world_sea_links[here]
		var/list/stretches = islist(sides) ? sides[side] : null
		if (!islist(stretches))
			continue
		for (var/dest in stretches)
			var/list/S = stretches[dest]
			if (f >= S[1] && f <= S[2])
				return list(dest, region_edge_opposite(side), S[2] > S[1] ? (f - S[1]) / (S[2] - S[1]) : 0)
	return null

// The name of a region for the crew.
/proc/sea_edge_place(id)
	var/list/peer = shard_group && shard_group.peers ? shard_group.peers[id] : null
	if (peer)
		return peer["name"]
	var/list/ocean = world_oceans[id]
	return islist(ocean) ? ocean[3] : id

// ---------------------------------------------------------------- leaving

// Why she cannot sail over this edge now, or null.
/obj/structure/hull_tiller/proc/sea_edge_refusal(mob/living/human/H, list/route)
	if (!islist(route))
		return "Nothing lies beyond this edge of the chart."
	if (voyage)
		return "She is on a voyage. Her crew sail on with it."
	if (route[1] == shard_group.region)
		return sea_edge_seaworthy_refusal()
	var/reason = crossing_refusal(H)
	if (reason)
		return reason
	if (!shard_group.peers[route[1]])
		return "[sea_edge_place(route[1])] is not open to ships yet."
	reason = sea_edge_seaworthy_refusal()
	if (reason)
		return reason
	var/load = sea_crossing_load(src)
	if (istext(load))
		return load
	return landfall_rest_refusal() || crossing_hold_refusal(route[1])

// Open water is no place for a raft: a mast or a running engine, and hands to
// work her. Why she cannot put out into it, or null.
/obj/structure/hull_tiller/proc/sea_edge_seaworthy_refusal()
	craft.fit_drives()
	if (craft.max_speed() < VESSEL_SPEED_SLOW)
		return "She cannot sail the open sea without a way to sail: rig a mast or fit a running engine."
	if (length(voyage_crew()) < SEA_EDGE_MIN_CREW)
		return "The open sea needs at least [SEA_EDGE_MIN_CREW] of her crew aboard and awake."
	return null

// Round the world in an ocean whose west and east edges join: she comes out
// on the other side of this same sea at the matching place. Why she could
// not, or null.
/obj/structure/hull_tiller/proc/sea_edge_wrap(list/route)
	var/datum/craft_body/built/B = craft ? craft.body : null
	if (!istype(B))
		return "She is not afloat."
	var/turf/P = sea_edge_anchorage(B.offsets, list(route[2], route[3]), route[1])
	if (!P)
		return "There is no open water to sail into on the far side."
	if (!B.move_to(P.x, P.y, B.dir))
		return B.last_refusal || "She cannot sail on."
	log_game("Sea edge: the [craft.name] sails round the world into the [route[2]] of [route[1]] at [P.x],[P.y].")
	craft.crew_message(SPAN_NOTICE("The [craft.name] sails on round the world, and the [route[2]] of the [sea_edge_place(route[1])] opens ahead."))
	return null

/obj/structure/hull_tiller/proc/sea_edge_menu(mob/living/human/H)
	var/datum/craft_body/built/B = craft ? craft.body : null
	var/list/route = istype(B) ? B.sea_edge_link() : null
	var/reason = sea_edge_refusal(H, route)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	var/place = sea_edge_place(route[1])
	var/wraps = route[1] == shard_group.region
	if (wraps)
		if (WWinput(H, "Sail on round the world into the [route[2]] of the [place]?", craft.name, "Stay", list("Sail on", "Stay")) != "Sail on" || get_dist(H, src) > 1 || !craft)
			return
	else if (WWinput(H, "Sail on over the horizon to [place]? Everyone and everything aboard goes with her; whoever stays ashore is left behind.", craft.name, "Stay", list("Sail on", "Stay")) != "Sail on" || get_dist(H, src) > 1 || !craft)
		return
	// The prompt slept: she may have drifted, or been sent elsewhere.
	B = craft.body
	var/list/now = istype(B) ? B.sea_edge_link() : null
	if (!islist(now) || now[1] != route[1])
		to_chat(H, SPAN_WARNING("She has drifted off that edge of the chart."))
		return
	reason = sea_edge_refusal(H, now)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	log_game("Sea edge: [key_name(H)] sails the [craft.name] on to [now[1]] ([now[2]], [round(now[3], 0.01)]).")
	var/result = wraps ? sea_edge_wrap(now) : cross(now[1], H, null, list(now[2], now[3]))
	if (result)
		to_chat(H, SPAN_WARNING(result))

// ---------------------------------------------------------------- arriving

// TRUE when a payload's sea edge is absent or well formed.
/proc/sea_edge_payload_ok(list/P)
	var/list/E = P["sea_edge"]
	if (isnull(E))
		return TRUE
	return islist(E) && E.len == 2 && !!region_edge_dir(E[1]) && isnum(E[2]) && E[2] >= 0 && E[2] <= 1 && islist(P["ship"])

// Where a ship with these offsets comes out from region from, arriving on
// side at fraction along it (sea_edge_link()). A pivot turf, or null.
/proc/sea_edge_anchorage(list/offsets, list/E, from, list/hold = null, list/upper = null)
	var/side = E[1]
	var/f = E[2]
	var/list/O = list(0, 0, 0, 0)
	for (var/list/o in offsets)
		O[1] = min(O[1], o[1])
		O[2] = min(O[2], o[2])
		O[3] = max(O[3], o[1])
		O[4] = max(O[4], o[2])
	var/z = map ? map.edge_crossing_z : 1
	// Where along the side, and the line she is put on: the map's edge, or
	// beside an island's box of breakers.
	var/along
	var/line
	var/out = 1 // which way is away from the edge or box, along the line's axis
	var/list/boxes = world_insets[shard_group.region]
	var/list/X = islist(boxes) ? boxes[from] : null
	if (islist(X))
		switch (side)
			if ("north")
				along = X[1] + f * (X[3] - X[1])
				line = X[4] + 2 - O[2]
			if ("south")
				along = X[1] + f * (X[3] - X[1])
				line = X[2] - 2 - O[4]
				out = -1
			if ("east")
				along = X[2] + f * (X[4] - X[2])
				line = X[3] + 2 - O[1]
			else
				along = X[2] + f * (X[4] - X[2])
				line = X[1] - 2 - O[3]
				out = -1
	else
		var/list/sides = world_sea_links[shard_group.region]
		var/list/stretches = islist(sides) ? sides[side] : null
		var/list/S = islist(stretches) && islist(stretches[from]) ? stretches[from] : list(0, 1)
		var/g = S[1] + f * (S[2] - S[1])
		var/span = (side == "north" || side == "south") ? world.maxx : world.maxy
		along = 1 + g * (span - 1)
		switch (side)
			if ("north")
				line = world.maxy - 2 - O[4]
				out = -1
			if ("south")
				line = 3 - O[2]
			if ("east")
				line = world.maxx - 2 - O[3]
				out = -1
			else
				line = 3 - O[1]
	along = round(along)
	for (var/depth = 0, depth <= SEA_EDGE_DEPTH, depth += 2)
		for (var/off = 0, off <= SEA_EDGE_SEARCH, off += 2)
			for (var/sign in list(1, -1))
				if (!off && sign < 0)
					continue
				var/a = along + off * sign
				var/l = line + depth * out
				var/x = (side == "north" || side == "south") ? a : l
				var/y = (side == "north" || side == "south") ? l : a
				if (x + O[1] < 1 || y + O[2] < 1 || x + O[3] > world.maxx || y + O[4] > world.maxy)
					continue
				var/turf/P = locate(x, y, z)
				if (P && sea_crossing_water(P) && sea_crossing_fits(offsets, x, y, z, hold, upper))
					return P
	return null

#undef SEA_EDGE_BAND
#undef SEA_EDGE_MIN_CREW
#undef SEA_EDGE_SEARCH
#undef SEA_EDGE_DEPTH
