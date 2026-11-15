// ============================================================
// Sea lanes between known lands (docs/ship-voyage.md)
// ------------------------------------------------------------
// The Americas and Gaia lie across the sea from each other. A ship off the
// edge of one can set out on a voyage to the other like a voyage on the world
// chart (ship_voyage.dm): a mast or a running engine, rations for the days at
// sea, storms on the way. At landfall she crosses to that world like any ship
// leaving these waters (ship_crossing.dm) and comes in off the coast that faces
// home. No world chart or expedition slot is needed: the lands are already
// open, so a single sailor may make the voyage.
//
// A map lists its lanes in sea_lanes: region id = list("tiles" = chart tiles
// of sailing, "coast" = the side of this map the lane comes in on, "bearing" =
// where that land lies, for the crew). A lane is offered only while the region
// is in this world's group and up or wakeable.
// ============================================================

/obj/map_metadata/var/list/sea_lanes = null

// The lane from this world to region id, or null.
/proc/sea_lane(id)
	if (!map || !islist(map.sea_lanes) || !istext(id))
		return null
	var/list/lane = map.sea_lanes[id]
	if (!islist(lane) || !isnum(lane["tiles"]) || lane["tiles"] < 1)
		return null
	return lane

// "Label" = list(region id, tiles) for every known land a ship can sail for
// from here now.
/proc/sea_lane_destinations()
	. = list()
	if (!map || !islist(map.sea_lanes) || !shard_group || !shard_group.enabled)
		return
	for (var/id in map.sea_lanes)
		var/list/lane = sea_lane(id)
		var/list/peer = shard_group.peers[id]
		if (!lane || !islist(peer) || id == shard_group.region)
			continue
		if (peer["state"] == "STOPPED" || !(peer["state"] == "UP" || shard_group.peer_wakeable(id)))
			continue
		var/tiles = round(lane["tiles"])
		var/bearing = istext(lane["bearing"]) ? " to the [lane["bearing"]]" : ""
		.["[peer["name"]], across the sea[bearing]: [tiles] tile\s, about [tiles] minute\s"] = list(id, tiles)

// The side of this map a ship coming from region from makes landfall on, or null.
/proc/sea_lane_coast(from)
	var/list/lane = sea_lane(from)
	return lane ? text2dir_side(lane["coast"]) : null
