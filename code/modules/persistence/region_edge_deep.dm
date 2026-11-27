// ============================================================
// Walking over a land edge underground (docs/edge-crossings.md, "Underground")
// ------------------------------------------------------------
// The land links (world_links.dm) hold below the surface too: a tunnel dug
// out to a linked edge on an underground level leads on into the same depth
// of the land beyond. The walker is asked and travels exactly as on the
// surface (region_edge.dm); the crossing carries a fourth field, the depth.
//
// Every underground level has a bedrock rim along the map's border
// (dug_underground_cell), so underground the edge is the row just inside it:
// a walker who reaches the rim at a linked stretch has reached the edge.
// Underground there is no dry ground to count along the border, so the place
// along it is reckoned over the whole stretch. On arrival the far land's level
// at that depth is added if nobody has dug down to it yet (underground_create,
// dug_underground.dm), and the tunnel is dug in from the border to where the
// walker comes out, so the way back is open. Hot rock and lava are never dug
// into; the walker comes out at the nearest place along the stretch that is
// clear of them, or on the surface if there is none.
//
// The open-air levels above the surface have no walk links: nothing stands at
// the same height on the far side to walk out onto. Planes cross there
// (aircraft_edge.dm).
// ============================================================

#define REGION_EDGE_DEEP_SEARCH 24
// Tiles in from the border the walker comes out, as on the surface.
#define REGION_EDGE_DEEP_INSET 3

// The depth below the surface T lies at, when a linked edge may be walked on
// there: an underground level of a map whose land links hold, else 0.
/proc/region_edge_deep_depth(turf/T)
	if (!istype(T) || !map || T.z == map.edge_crossing_z)
		return 0
	return underground_depth_of(T.z)

// The side of a linked edge underground cell T lies on, or null.
/proc/region_edge_deep_side(turf/T)
	if (!region_edge_deep_depth(T))
		return null
	var/list/links = region_edge_links()
	var/side = region_edge_deep_rim_side(T)
	if (!side || !links || !links[side] || !region_edge_ground(T))
		return null
	return region_edge_deep_destination(side, region_edge_along(side, T)) ? side : null

// The side of the bedrock rim T lies against, or null.
/proc/region_edge_deep_rim_side(turf/T)
	if (T.y == 2) return "south"
	if (T.y == world.maxy - 1) return "north"
	if (T.x == 2) return "west"
	if (T.x == world.maxx - 1) return "east"
	return null

// TRUE when T lies against the bedrock rim of an underground level.
/proc/region_edge_deep_on_rim(turf/T)
	return region_edge_deep_rim_side(T) && region_edge_deep_depth(T)

// The region a walker underground at position a along side walks on into.
/proc/region_edge_deep_destination(side, a)
	for (var/id in region_edge_destinations(side))
		var/list/bounds = region_edge_bounds(side, id)
		if (bounds && a >= bounds[1] && a <= bounds[2])
			return id
	return null

// How far along the whole stretch to id position a is, 0 to 1.
/proc/region_edge_deep_fraction(side, id, a)
	var/list/bounds = region_edge_bounds(side, id)
	if (!bounds || bounds[2] <= bounds[1])
		return 0.5
	return round(clamp((a - bounds[1]) / (bounds[2] - bounds[1]), 0, 1), 0.001)

// TRUE for a cell underground that a walker can be dug out into.
/proc/region_edge_deep_diggable(turf/T)
	if (!T || T.quarry_hardness() || istype(T, /turf/floor/dirt/underground/hot) || istype(T, /turf/floor/lava) || istype(T, /turf/wall/rockwall/bedrock) || istype(T, /turf/floor/beach/water))
		return FALSE
	for (var/atom/movable/M in T)
		if (M.density && !istype(M, /atom/movable/lighting_overlay))
			return FALSE
	return TRUE

// Opens one cell of the tunnel: forms it, and digs it out if it is rock.
/proc/region_edge_deep_open(turf/T)
	T = dug_underground_form(T)
	if (!T || !region_edge_deep_diggable(T))
		return null
	if (istype(T, /turf/wall) || istype(T, /turf/floor/dirt/underground))
		T = T.ChangeTurf(/turf/floor/dirt)
	return T

// Where a walker who crossed an edge at depth comes out on side, as far along
// the stretch to id as fraction f: the tunnel is dug in from the rim to
// there. Null when this land has no such stretch or no level can be added.
/proc/region_edge_deep_arrival(side, id, f, depth)
	var/list/bounds = region_edge_bounds(side, id)
	if (!bounds || !depth)
		return null
	var/z = underground_z_at(depth)
	if (!z && depth == underground_levels().len + 1 && depth <= underground_depth_limit())
		if (underground_create(depth))
			z = underground_z_at(depth)
	if (!z)
		return null
	var/at = bounds[1] + round(f * (bounds[2] - bounds[1]))
	for (var/off = 0, off <= REGION_EDGE_DEEP_SEARCH, off++)
		for (var/sign in list(1, -1))
			if (!off && sign < 0)
				continue
			var/a = at + off * sign
			if (a < bounds[1] || a > bounds[2])
				continue
			var/list/line = list()
			for (var/d = 1 to REGION_EDGE_DEEP_INSET + 1)
				var/turf/T = region_edge_deep_turf(side, a, d, z)
				T = dug_underground_form(T)
				if (!region_edge_deep_diggable(T))
					line = null
					break
				line += T
			if (!line)
				continue
			var/turf/out = null
			for (var/turf/T in line)
				out = region_edge_deep_open(T)
			if (out)
				return out
	return null

/proc/region_edge_deep_turf(side, a, depth, z)
	switch (side)
		if ("north") return locate(a, world.maxy - depth, z)
		if ("south") return locate(a, 1 + depth, z)
		if ("east") return locate(world.maxx - depth, a, z)
		if ("west") return locate(1 + depth, a, z)
	return null

#undef REGION_EDGE_DEEP_SEARCH
#undef REGION_EDGE_DEEP_INSET
