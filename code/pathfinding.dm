//ported from goonstation 2020 release. WIP

/proc/AStar(start, end, adjacent, heuristic, maxtraverse = 30, adjacent_param = null, exclude = null)
	var/list/open = list(start), list/nodeG = list(), list/nodeParent = list(), P = 0
	while (P++ < open.len)
		var/T = open[P], TG = nodeG[T]
		if (T == end)
			var/list/R = list()
			while (T)
				R.Insert(1, T)
				T = nodeParent[T]
			return R
		var/list/other = call(T, adjacent)(adjacent_param)
		for (var/next in other)
			if (open.Find(next) || next == exclude) continue
			var/G = TG + other[next], F = G + call(next, heuristic)(end)
			for (var/i = P; i <= open.len;)
				if (i++ == open.len || open[open[i]] >= F)
					open.Insert(i, next)
					open[next] = F
					break
			nodeG[next] = G
			nodeParent[next] = T

		if (P > maxtraverse)
			return

/proc/cirrAstar(turf/start, turf/goal, var/min_dist=0, proc/adjacent, proc/heuristic, maxtraverse = 30, adjacent_param = null, exclude = null)

	var/list/closedSet = list()
	var/list/openSet = list(start)
	var/list/cameFrom = list()

	var/list/gScore = list()
	var/list/fScore = list()
	gScore[start] = 0
	fScore[start] = heuristic(start, goal)
	var/traverse = 0

	while(openSet.len > 0)
		var/current = pickLowest(openSet, fScore)
		if(distance(current, goal) <= min_dist)
			return reconstructPath(cameFrom, current)

		openSet -= current
		closedSet += current
		var/list/neighbors = getNeighbors(current, alldirs)
		for(var/neighbor in neighbors)
			if(neighbor in closedSet)
				continue // already checked this one
			var/tentativeGScore = gScore[current] + distance(current, neighbor)
			if(!(neighbor in openSet))
				openSet += neighbor
			else if(tentativeGScore >= (gScore[neighbor] || 1.#INF))
				continue // this is not a better route to this node

			cameFrom[neighbor] = current
			gScore[neighbor] = tentativeGScore
			fScore[neighbor] = gScore[neighbor] + heuristic(neighbor, goal)
		traverse += 1
		if(traverse > maxtraverse)
			return null // it's taking too long, abandon
	return null // if we reach this part, there's no more nodes left to explore

/proc/heuristic(turf/start, turf/goal)
	if(!start || !goal)
		return null // yes, null, not a number, i need to track down why nulls are being passed in as turfs so i'm throwing this up the stack
	// let's just do manhattan for now
	return abs(start.x - goal.x) + abs(start.y - goal.y)

/proc/distance(turf/start, turf/goal)
	if(!start || !goal)
		return null
	var/dx = goal.x - start.x
	var/dy = goal.y - start.y
	return sqrt(dx*dx + dy*dy)

/proc/pickLowest(list/options, list/values)
	if(options.len == 0)
		return null // you idiot
	var/lowestScore = 1.#INF
	for(var/option in options)
		if(option in values)
			var/score = values[option]
			if(score < lowestScore)
				lowestScore = score
				. = option
		else
			continue // if we have no score for an option, ignore it

/proc/reconstructPath(list/cameFrom, turf/current)
	var/list/totalPath = list(current)
	while(current in cameFrom)
		current = cameFrom[current]
		totalPath += current
	// reverse the path
	. = list()
	for(var/i = totalPath.len to 1 step -1)
		. += totalPath[i]
	return .

/proc/getNeighbors(turf/current, list/directions)
	. = list()
	// handle cardinals straightforwardly
	var/list/cardinalTurfs = list()
	for(var/direction in cardinal)
		if(direction in directions)
			var/turf/T = get_step(current, direction)
			cardinalTurfs["[direction]"] = 0 // can't pass
			if(T && checkTurfPassable(T))
				. += T
				cardinalTurfs["[direction]"] = 1 // can pass

/proc/checkTurfPassable(turf/T)
	if(!T)
		return 0 // can't go on a turf that doesn't exist!!
	if(T.density) // simplest case
		return 0
	for(var/atom/O in T.contents)
		if (O.density) // && !(O.flags & ON_BORDER)) -- fuck you, windows, you're dead to me
			if (istype(O, /obj/structure/simple_door))
				var/obj/structure/simple_door/D = O
				if (D.locked)
					return 0 // a blocked door is a blocking door
				else
					D.Open()
			if (ismob(O))
				var/mob/M = O
				if (M.anchored)
					return 0 // an anchored mob is a blocking mob
				else
			return 0 // not a special case, so this is a blocking object
	return 1

/******************************************************************/
// Navigation procs
// Used for A-star pathfinding

// Returns the surrounding cardinal turfs with open links
// Including through doors if openable
/turf/proc/CardinalTurfsWithAccess()
	var/L[] = new()

	for(var/d in cardinal)
		var/turf/T = get_step(src, d)
		if (T && !T.density)
			if(checkTurfPassable(T))
				L.Add(T)
	return L

/mob/living/simple_animal/hostile/human/proc/do_movement()
	if (!target_obj)
		return
	walk(src, 0)
	if(src.found_path)
		if(src.found_path.len > 0)
			// follow the path
			src.found_path.Cut(1, 2)
			var/turf/next
			if(src.found_path.len >= 1)
				next = src.found_path[1]
			else
				next = get_turf(target_obj)
			walk_to(src, next, 0, 4)
			if(get_dist(get_turf(src), next) > 1)
				get_path()
	else
		// get a path
		get_path()

/mob/living/simple_animal/hostile/human/proc/get_path()
	if(!target_obj)
		return 0
	src.found_path = cirrAstar(get_turf(src), get_turf(target_obj), 0, null, /proc/heuristic, 60)
	if(!src.found_path) // no path :C
		return 0
	return 1