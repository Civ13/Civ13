// Nomad visits by boat (docs/nomad-raids.md#crossing-water).
//
// A party that cannot walk to its target from the map edge (the target is on
// an island, or across a river with no ford) comes by water instead. It
// starts on unseen deep water at a map edge, each member on their own raft,
// and paddles in single file along the route agent_route_search() finds to
// the first dry tile by the target. The rafts stay moored there; when the
// party leaves, its members walk back to the landing, board, and paddle out
// to where they came from.
//
// Rafts are spawned for the visit and never saved. A raft whose rider fell
// stays where it is moored until the visit ends.

#define NOMAD_BOAT_STEP 12 // deciseconds per raft tile, a raft's own speed
#define NOMAD_BOAT_GAP 2 // tiles between rafts in the file
#define NOMAD_BOAT_TRIES 12 // water edge spots tried
#define NOMAD_BOAT_REACH 3 // how close to the target the landing must be reachable

/datum/nomad_raid
	var/tmp/list/sail_path // water turfs from the map edge to the last one before the landing
	var/tmp/turf/landing
	var/tmp/list/sail_pos = list() // member = index on sail_path (below 1: waiting to set off)
	var/tmp/list/sail_dir = list() // member = 1 outbound, -1 homeward
	var/tmp/list/rafts = list() // member = their raft
	var/tmp/next_sail = 0

/proc/nomad_raid_land_reachable(turf/origin, turf/goal)
	return agent_route_search(origin, goal, NOMAD_BOAT_REACH, FALSE) ? TRUE : FALSE

// Unseen open deep water at a map edge with one water crossing to the target.
// Returns list(turf, edge, path, landing) or null.
/proc/nomad_raid_water_site(turf/target)
	if (!target)
		return null
	var/list/edges = list("west" = target.x - 1, "east" = world.maxx - target.x, "south" = target.y - 1, "north" = world.maxy - target.y)
	var/tries = 0
	while (edges.len && tries < NOMAD_BOAT_TRIES)
		var/best = null
		for (var/edge in edges)
			if (isnull(best) || edges[edge] < edges[best])
				best = edge
		var/reach = min(edges[best] - 2, NOMAD_RAID_EDGE_LIMIT)
		edges -= best
		if (reach < NOMAD_RAID_VIEW_MARGIN)
			continue
		// Scan along the edge for water, nearest the target's line first.
		for (var/i = 0, i <= NOMAD_RAID_EDGE_SPREAD * 2 && tries < NOMAD_BOAT_TRIES, i++)
			var/side = (i % 2 ? 1 : -1) * round((i + 1) / 2)
			var/x = target.x
			var/y = target.y
			switch (best)
				if ("west")
					x -= reach
					y += side
				if ("east")
					x += reach
					y += side
				if ("south")
					y -= reach
					x += side
				if ("north")
					y += reach
					x += side
			var/turf/T = locate(clamp(x, 2, world.maxx - 1), clamp(y, 2, world.maxy - 1), target.z)
			if (!agent_deep_water(T) || ecology_visible_to_players(T, NOMAD_RAID_VIEW_MARGIN))
				continue
			tries++
			var/list/crossing = nomad_raid_crossing(T, target)
			if (crossing)
				crossing["edge"] = best
				return crossing
	return null

// The water leg from a deep water start to the target, if it is the only one.
/proc/nomad_raid_crossing(turf/start, turf/target)
	var/list/path = agent_route_search(start, target, NOMAD_BOAT_REACH, TRUE)
	if (!path || path.len < 2)
		return null
	var/list/legs = agent_route_legs(path)
	if (!legs.len)
		return null
	var/list/first = legs[1]
	if (first["mode"] != "boat")
		return null
	for (var/i = 2, i <= legs.len, i++)
		var/list/leg = legs[i]
		if (leg["mode"] == "boat")
			return null // more than one crossing: the party would be stranded halfway
	var/water = length(first["moves"])
	if (path.len < water + 2)
		return null
	return list("turf" = start, "path" = path.Copy(1, water + 2), "landing" = path[water + 2])

// Called from setup(): when the edge site cannot reach the target on foot,
// switch to a water start. Returns the new site, the old one, or null.
/datum/nomad_raid/proc/plan_crossing(list/site)
	if (site && nomad_raid_land_reachable(site["turf"], target))
		return site
	var/list/crossing = nomad_raid_water_site(target)
	if (!crossing)
		return site // walk as far as the land goes; the march limit sends them home
	sail_path = crossing["path"]
	landing = crossing["landing"]
	return crossing

// Each member on a raft at the water edge, in single file.
/datum/nomad_raid/proc/launch_boats()
	var/i = 0
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in members)
		var/obj/structure/vehicle/raft/R = new(sail_path[1])
		R.should_save = FALSE
		R.name = "[clan] raft"
		rafts[M] = R
		sail_pos[M] = 1 - i * NOMAD_BOAT_GAP
		sail_dir[M] = 1
		order_halt(M)
		M.forceMove(sail_path[1])
		i++
	set_state("sail", "crossing the water to [landing.x],[landing.y]")

// Moves every raft one tile along the water route.
/datum/nomad_raid/proc/sail_step()
	if (world.time < next_sail || !sail_path)
		return
	next_sail = world.time + NOMAD_BOAT_STEP
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in sail_pos.Copy())
		if (QDELETED(M) || M.stat == DEAD)
			sail_pos -= M
			sail_dir -= M
			continue
		var/index = sail_pos[M] + sail_dir[M]
		sail_pos[M] = index
		var/obj/structure/vehicle/raft/R = rafts[M]
		if (sail_dir[M] > 0)
			if (index < 1)
				continue
			if (index > sail_path.len)
				go_ashore(M)
				continue
		else if (index < 1)
			sail_pos -= M
			sail_dir -= M
			rafts -= M
			if (R && !QDELETED(R))
				qdel(R)
			escape(M)
			continue
		var/turf/T = sail_path[index]
		if (R && !QDELETED(R))
			R.forceMove(T)
		M.forceMove(T)
		order_halt(M)

/datum/nomad_raid/proc/go_ashore(mob/living/simple_animal/hostile/human/nomad_raider/M)
	sail_pos -= M
	sail_dir -= M
	var/turf/spot = landing
	if (nomad_raid_ground_error(spot) == "occupied")
		for (var/turf/T in orange(1, landing))
			if (!agent_deep_water(T) && !nomad_raid_ground_error(T))
				spot = T
				break
	M.forceMove(spot)

/datum/nomad_raid/proc/tick_sail(list/alive)
	sail_step()
	for (var/M in sail_pos)
		if (sail_dir[M] > 0)
			return
	set_state("march", "landed at [landing.x],[landing.y]")

// Leaving by water: walk to the landing, board, paddle out. TRUE when the
// member is handled here.
/datum/nomad_raid/proc/leave_by_boat(mob/living/simple_animal/hostile/human/nomad_raider/M)
	if (!sail_path)
		return FALSE
	if (M in sail_pos)
		sail_dir[M] = -1 // turned back mid-crossing, or already paddling out
		return TRUE
	if (get_dist(M, landing) > 1)
		if (!M.target_mob)
			order_move(M, landing)
		return TRUE
	var/obj/structure/vehicle/raft/R = rafts[M]
	var/turf/moor = sail_path[sail_path.len]
	if (!R || QDELETED(R))
		R = new(moor)
		R.should_save = FALSE
		R.name = "[clan] raft"
		rafts[M] = R
	R.forceMove(moor)
	order_halt(M)
	M.forceMove(moor)
	sail_pos[M] = sail_path.len
	sail_dir[M] = -1
	return TRUE

/datum/nomad_raid/proc/clear_boats()
	for (var/M in rafts)
		var/obj/structure/vehicle/raft/R = rafts[M]
		if (R && !QDELETED(R))
			qdel(R)
	rafts.Cut()
	sail_pos.Cut()
	sail_dir.Cut()

#undef NOMAD_BOAT_STEP
#undef NOMAD_BOAT_GAP
#undef NOMAD_BOAT_TRIES
