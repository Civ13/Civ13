// Rail networks. Rails on side-by-side tiles join into one network, the way
// cables join into a power net (machinery/cables.dm): turns, switches and
// branches all count, so a line may bend and fork. A network is found by a
// breadth-first walk from any of its rails; nothing about it is saved.
//
// Every rail laid or removed bumps rail_network_serial, so callers can keep a
// result until the track changes (party_train.dm's station check does).

#define RAIL_NETWORK_VISIT_LIMIT 50000 // rails walked at most in one search

var/global/rail_network_serial = 0

/obj/structure/rails/New()
	..()
	rail_network_serial++

/obj/structure/rails/Destroy()
	rail_network_serial++
	return ..()

/proc/rail_at(turf/T)
	return T && (locate(/obj/structure/rails) in T)

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
