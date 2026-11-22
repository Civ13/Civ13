// ============================================================
// The lands of the Earth and the ways between them (docs/ship-voyage.md)
// ------------------------------------------------------------
// Every continent of the region group has a place on one shared layout
// (continent_layout, in chart tiles) and the coasts of its map that face open
// sea. From the layout come the routes between continents:
//
// - By sea: a ship off the edge of one coastal continent can set out on a
//   voyage to any other (ship_voyage.dm). A tile of the layout is a minute
//   under sail, as on the world chart. She makes landfall off the coast that
//   faces where she came from.
// - By air: an aircraft flying off the edge of any continent can fly on to any
//   other with a flight level (aircraft_routes.dm).
//
// A route is offered only while the other continent's world is in this
// world's group and up or able to wake. Region ids are the host's (earth.json).
// ============================================================

// continent_layout (region id = list(x, y, coasts, flight)) is written from
// tools/world_links/world_links.json into code/modules/persistence/world_links.dm.

// This map's own open-sea edges, when they are not the layout's: a region's
// world can move to a new map (the Earth-shaped Europe) before the layout
// entry for its id changes.
/obj/map_metadata/var/list/sea_coasts = null

/proc/continent_place(id)
	if (!istext(id))
		return null
	var/list/place = continent_layout[id]
	return islist(place) && place.len == 4 ? place : null

/proc/continent_coastal(id)
	var/list/place = continent_place(id)
	return place && length(place[3]) > 0

// Tiles of sailing between two continents, or null when either is not laid out.
/proc/continent_distance(from, dest)
	var/list/A = continent_place(from)
	var/list/B = continent_place(dest)
	if (!A || !B)
		return null
	return max(1, max(abs(A[1] - B[1]), abs(A[2] - B[2])))

// The compass word for where continent dest lies from continent from.
/proc/continent_bearing(from, dest)
	var/list/A = continent_place(from)
	var/list/B = continent_place(dest)
	if (!A || !B)
		return null
	var/dx = B[1] - A[1]
	var/dy = B[2] - A[2]
	var/ns = dy * 2 > abs(dx) ? "north" : (-dy * 2 > abs(dx) ? "south" : "")
	var/ew = dx * 2 > abs(dy) ? "east" : (-dx * 2 > abs(dy) ? "west" : "")
	return "[ns][ew]" || "near"

// Map sides facing continent toward, nearest first: the main axis, then the
// other axis, then the two away from it.
/proc/continent_sides_toward(here, toward)
	var/list/A = continent_place(here)
	var/list/B = continent_place(toward)
	if (!A || !B)
		return list()
	var/dx = B[1] - A[1]
	var/dy = B[2] - A[2]
	var/ew = dx >= 0 ? EAST : WEST
	var/ns = dy >= 0 ? NORTH : SOUTH
	return abs(dx) >= abs(dy) ? list(ew, ns, turn(ns, 180), turn(ew, 180)) : list(ns, ew, turn(ew, 180), turn(ns, 180))

// "Label" = list(region id, tiles) for every continent a ship can sail for
// from here now.
/proc/sea_lane_destinations()
	. = list()
	if (!shard_group || !shard_group.enabled || !continent_coastal(shard_group.region))
		return
	for (var/id in continent_layout)
		if (id == shard_group.region || !continent_coastal(id))
			continue
		var/list/peer = shard_group.peers[id]
		if (!islist(peer) || shard_group.peer_closed(id) || !(peer["state"] == "UP" || shard_group.peer_wakeable(id)))
			continue
		var/tiles = continent_distance(shard_group.region, id)
		.["[peer["name"]], across the sea to the [continent_bearing(shard_group.region, id)]: [tiles] tile\s, about [tiles] minute\s"] = list(id, tiles)

// The sides of this map a ship from continent from makes landfall off, best
// first: its coasts facing from, its other coasts. Empty when from is unknown.
/proc/sea_lane_sides(from)
	. = list()
	var/list/here = continent_place(shard_group ? shard_group.region : null)
	if (!here || !continent_place(from))
		return
	var/list/coasts = list()
	for (var/side in ((map && length(map.sea_coasts)) ? map.sea_coasts : here[3]))
		coasts += text2dir_side(side)
	for (var/d in continent_sides_toward(shard_group.region, from))
		if (d in coasts)
			. += d
	for (var/d in coasts)
		if (!(d in .))
			. += d
