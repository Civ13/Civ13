// Rail networks. Rails on side-by-side tiles join into one network, the way
// cables join into a power net (machinery/cables.dm): turns, switches and
// branches all count, so a line may bend and fork. A network is found by a
// breadth-first walk from any of its rails; nothing about it is saved.
//
// Every rail laid or removed bumps rail_network_serial (rails/New and Destroy
// in trains.dm), so callers can keep a result until the track changes
// (party_train.dm's station check does).

#define RAIL_NETWORK_VISIT_LIMIT 50000 // rails walked at most in one search

var/global/rail_network_serial = 0

/proc/rail_at(turf/T)
	return T && (locate(/obj/structure/rails) in T)

// Whether T is straight plain track running along heading: every rail there
// is plain (no switch, curve, rotator or turntable) and lies that way. Car
// kits, warehouse bays and arriving trains all ask this.
/proc/rail_straight_along(turf/T, heading)
	if (!T || !(heading in cardinal))
		return FALSE
	var/found = FALSE
	for (var/obj/structure/rails/R in T)
		if (istype(R, /obj/structure/rails/split) || istype(R, /obj/structure/rails/turn) || istype(R, /obj/structure/rails/arc) || istype(R, /obj/structure/rails/rotate) || istype(R, /obj/structure/rails/turntable))
			return FALSE
		if (R.dir != heading && R.dir != OPPOSITE_DIR(heading))
			return FALSE
		found = TRUE
	return found

// The way the track on T runs (a cardinal), or null: fixtures dug under the
// line, such as ash and drop pits, lie along it.
/proc/rail_dir_at(turf/T)
	var/obj/structure/rails/R = rail_at(T)
	return (R && (R.dir in cardinal)) ? R.dir : null

/proc/rail_turf_on_map_edge(turf/T)
	return T && (T.x == 1 || T.y == 1 || T.x == world.maxx || T.y == world.maxy)

// Whether any rail network starting on one of the turfs in starts reaches a
// tile on the edge of the map. Turfs without rails are ignored. Never sleeps.
/proc/rail_network_reaches_edge(list/starts)
	var/list/pending = list()
	var/list/seen = list()
	for(var/turf/T in starts)
		if(!seen[T] && rail_at(T))
			seen[T] = TRUE
			pending += T
	var/index = 1
	while(index <= pending.len)
		if(index > RAIL_NETWORK_VISIT_LIMIT)
			log_debug("Rail network: a search from [pending[1]] stopped after [RAIL_NETWORK_VISIT_LIMIT] rails.")
			return FALSE
		var/turf/T = pending[index++]
		if(rail_turf_on_map_edge(T))
			return TRUE
		for(var/d in cardinal)
			var/turf/next = get_step(T, d)
			if(next && !seen[next])
				seen[next] = TRUE
				if(rail_at(next))
					pending += next
	return FALSE

#undef RAIL_NETWORK_VISIT_LIMIT
