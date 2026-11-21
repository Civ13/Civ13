// ============================================================
// Planes over linked map edges (docs/ocean-regions.md, "By plane")
// ------------------------------------------------------------
// Where the host has switched on edge travel (shard_group edge_travel_oceans),
// a plane needs no menu to fly to another land: she flies off the edge of the
// map and comes out where her heading takes her. The world links table
// (world_links.dm) says what lies beyond each stretch of each edge.
//
// Oceans have no air level, so a plane flying into one is carried straight
// across it in the same heading: to an island set inside it (Gaia,
// Greenland) if her line crosses its box, else to the far edge and on to
// whatever lies beyond that. Crossing an ocean burns cruise fuel for its
// width, one leg of the existing crossing for every AIR_EDGE_LEG_TILES tiles
// of sea; a land that shares an edge is one leg. A plane short of fuel is
// stopped at the edge, as she is today, and stalls if she does not turn.
//
// The flight itself is the existing crossing (aircraft_crossing.dm air_cross):
// she is packed with her crew, travels in the pilot's payload, and is built
// in from the arrival edge, at the place along it that her line reaches.
// ============================================================

// Tiles of ocean a leg of flying covers.
#define AIR_EDGE_LEG_TILES 100
// Oceans and lands a single flight may pass over before it gives up.
#define AIR_EDGE_HOPS 6

/obj/structure/vehicleparts/axis/aircraft
	// The fraction along the arrival edge an edge flight comes in at.
	var/tmp/air_edge_along = null

// TRUE when planes in this world fly over linked map edges.
/proc/air_edge_travel_on()
	return sea_edge_travel_on()

/proc/air_edge_side(dir)
	switch (dir)
		if (NORTH) return "north"
		if (SOUTH) return "south"
		if (EAST) return "east"
		if (WEST) return "west"
	return null

// What lies over edge `side` of region `cur` at fraction f along it:
// list(region, arrival side, fraction along the arrival edge), or null.
/proc/air_edge_next(cur, side, f)
	var/ocean = sea_edge_inset_ocean(cur)
	if (ocean)
		return list(ocean, region_edge_opposite(side), f, cur)
	var/list/O = world_oceans[cur]
	if ((side == "west" || side == "east") && islist(O) && O.len >= 6 && islist(O[6]) && (("west" in O[6]) || ("east" in O[6])))
		return list(cur, region_edge_opposite(side), f)
	var/list/sides = world_sea_links[cur]
	var/list/stretches = islist(sides) ? sides[side] : null
	if (!islist(stretches))
		return null
	for (var/dest in stretches)
		var/list/S = stretches[dest]
		if (f >= S[1] && f <= S[2])
			return list(dest, region_edge_opposite(side), S[2] > S[1] ? (f - S[1]) / (S[2] - S[1]) : 0)
	return null

// Flies straight across an ocean. heading: the side she flies toward. x, y:
// where she starts, in the ocean's tiles. from_land: an island she has just
// left, not to be landed on again. Returns list(tiles flown, island id or
// null, arrival side, fraction along it).
/proc/air_edge_traverse(ocean, heading, x, y, from_land = null)
	var/list/O = world_oceans[ocean]
	var/w = O[1]
	var/h = O[2]
	var/best = null
	var/best_tiles = 0
	var/best_f = 0
	var/list/boxes = world_insets[ocean]
	if (islist(boxes))
		for (var/land in boxes)
			if (land == from_land)
				continue
			var/list/X = boxes[land]
			var/tiles = -1
			var/f = 0
			switch (heading)
				if ("east")
					if (y >= X[2] && y <= X[4] && X[1] >= x)
						tiles = X[1] - x
						f = (y - X[2]) / max(1, X[4] - X[2])
				if ("west")
					if (y >= X[2] && y <= X[4] && X[3] <= x)
						tiles = x - X[3]
						f = (y - X[2]) / max(1, X[4] - X[2])
				if ("north")
					if (x >= X[1] && x <= X[3] && X[2] >= y)
						tiles = X[2] - y
						f = (x - X[1]) / max(1, X[3] - X[1])
				if ("south")
					if (x >= X[1] && x <= X[3] && X[4] <= y)
						tiles = y - X[4]
						f = (x - X[1]) / max(1, X[3] - X[1])
			if (tiles >= 0 && (!best || tiles < best_tiles))
				best = land
				best_tiles = tiles
				best_f = f
	if (best)
		return list(best_tiles, best, region_edge_opposite(heading), clamp(best_f, 0, 1))
	switch (heading)
		if ("east") return list(w - x, null, heading, h > 1 ? clamp((y - 1) / (h - 1), 0, 1) : 0)
		if ("west") return list(x - 1, null, heading, h > 1 ? clamp((y - 1) / (h - 1), 0, 1) : 0)
		if ("north") return list(h - y, null, heading, w > 1 ? clamp((x - 1) / (w - 1), 0, 1) : 0)
	return list(y - 1, null, heading, w > 1 ? clamp((x - 1) / (w - 1), 0, 1) : 0)

// Where a plane leaving region `here` over edge `side` at fraction f comes
// down to land: list(region, arrival side, fraction along it, legs of
// flying), or text saying why there is nowhere.
/proc/air_edge_route(here, side, f)
	var/cur = here
	var/heading = side
	var/ocean_tiles = 0
	for (var/hop = 1 to AIR_EDGE_HOPS)
		var/list/next = air_edge_next(cur, heading, f)
		if (!next)
			return ocean_tiles ? "nothing lies beyond the sea that way" : "nothing lies beyond this edge"
		var/dest = next[1]
		if (!islist(world_oceans[dest]))
			if (!continent_flight(dest))
				return "there is no open sky to fly into over [sea_edge_place(dest)]"
			return list(dest, next[2], next[3], max(1, CEILING(ocean_tiles / AIR_EDGE_LEG_TILES, 1)))
		// Into an ocean: across it in the same heading.
		var/list/O = world_oceans[dest]
		var/x
		var/y
		if (next.len >= 4)
			// Off an island inside it: from that side of the island's box.
			var/list/X = world_insets[dest][next[4]]
			switch (heading)
				if ("east")
					x = X[3]
					y = X[2] + next[3] * (X[4] - X[2])
				if ("west")
					x = X[1]
					y = X[2] + next[3] * (X[4] - X[2])
				if ("north")
					y = X[4]
					x = X[1] + next[3] * (X[3] - X[1])
				else
					y = X[2]
					x = X[1] + next[3] * (X[3] - X[1])
		else
			switch (next[2])
				if ("west")
					x = 1
					y = 1 + next[3] * (O[2] - 1)
				if ("east")
					x = O[1]
					y = 1 + next[3] * (O[2] - 1)
				if ("south")
					y = 1
					x = 1 + next[3] * (O[1] - 1)
				else
					y = O[2]
					x = 1 + next[3] * (O[1] - 1)
		var/list/across = air_edge_traverse(dest, heading, round(x), round(y), next.len >= 4 ? next[4] : null)
		ocean_tiles += across[1]
		if (across[2])
			if (!continent_flight(across[2]))
				return "there is no open sky to fly into over [sea_edge_place(across[2])]"
			return list(across[2], across[3], across[4], max(1, CEILING(ocean_tiles / AIR_EDGE_LEG_TILES, 1)))
		cur = dest
		f = across[4]
	return "there is nothing but sea that way"

// Called by do_vehicle_check when she meets the map edge. TRUE when she has
// set off over it (the flight runs on its own); FALSE leaves her at the edge.
/obj/structure/vehicleparts/axis/aircraft/proc/air_edge_fly_on(m_dir)
	if (!air_edge_travel_on() || !driver || air_crossing_asking || air_crossing_hold > world.time)
		return FALSE
	var/side = air_edge_side(m_dir)
	var/turf/P = get_turf(src)
	if (!side || !P)
		return FALSE
	var/list/route = air_edge_route(shard_group.region, side, sea_edge_along(side, P.x, P.y))
	if (!islist(route))
		pilot_message(SPAN_WARNING("You are at the edge of the world: [route]. Turn back or you will stall."))
		return FALSE
	var/reason = air_crossing_refusal(driver)
	if (reason)
		pilot_message(SPAN_WARNING("You are at the edge of the land, but you cannot fly on: [reason]"))
		return FALSE
	air_crossing_asking = TRUE
	pilot_message(SPAN_NOTICE("You fly on over the edge of the land, toward [sea_edge_place(route[1])]."))
	addtimer(CALLBACK(src, PROC_REF(air_edge_cross), route, driver), 1)
	return TRUE

/obj/structure/vehicleparts/axis/aircraft/proc/air_edge_cross(list/route, mob/living/human/pilot)
	air_edge_along = route[3]
	var/result = air_cross(route[1], route[4], pilot)
	if (QDELETED(src))
		return
	air_edge_along = null
	air_crossing_asking = FALSE
	if (result)
		edge_blocked = TRUE
		pilot_message(SPAN_WARNING("[result] Turn back or you will stall."))

#undef AIR_EDGE_LEG_TILES
#undef AIR_EDGE_HOPS
