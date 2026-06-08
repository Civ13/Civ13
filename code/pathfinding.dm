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

/proc/cirrAstar(var/turf/start, var/turf/goal, var/min_dist=1, var/maxtraverse = 50)
	if(!start || !goal) return list()
	var/list/closedSet = list()
	var/list/openSet = list(start)
	var/list/cameFrom = list()

	var/list/gScore = list()
	var/list/fScore = list()
	var/list/passableCache = list() // Cache passability within this search
	
	gScore[start] = 0
	fScore[start] = heuristic(start, goal)
	var/traverse = 0

	while(openSet.len > 0)
		var/turf/current = pickLowest(openSet, fScore)
		if(!current) break
		
		if(get_dist(current, goal) <= min_dist)
			return reconstructPath(cameFrom, current)
			
		openSet -= current
		closedSet[current] = TRUE
		
		var/list/neighbors = getNeighbors(current, alldirs, passableCache)
		for(var/turf/neighbor in neighbors)
			if(closedSet[neighbor])
				continue // already checked this one
				
			// Scale base distance by terrain difficulty (move_delay) so the
			// pathfinder naturally avoids slow terrain (water, swamp, trenches).
			var/terrain_cost = 1 + (neighbor.move_delay ? neighbor.move_delay / 10 : 0)
			var/dist = ((current.x == neighbor.x || current.y == neighbor.y) ? 1 : 1.414) * terrain_cost
			var/tentativeGScore = gScore[current] + dist
			
			if(!(neighbor in openSet))
				openSet += neighbor
			else if(tentativeGScore >= (gScore[neighbor] || 1.#INF))
				continue // this is not a better route to this node

			cameFrom[neighbor] = current
			gScore[neighbor] = tentativeGScore
			fScore[neighbor] = tentativeGScore + heuristic(neighbor, goal)
			
		traverse += 1
		if(traverse > maxtraverse)
			return list() // it's taking too long, abandon
	return list() // if we reach this part, there's no more nodes left to explore

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
	var/lowestScore = 1.#INF
	var/best_option = null
	for(var/option in options)
		var/score = values[option]
		if(score < lowestScore)
			lowestScore = score
			best_option = option
	return best_option

/proc/reconstructPath(list/cameFrom, turf/current)
	var/list/totalPath = list(current)
	while(current in cameFrom)
		current = cameFrom[current]
		totalPath += current
	// reverse the path
	var/list/tlist = list()
	for(var/i = totalPath.len to 1 step -1)
		tlist += totalPath[i]
	return tlist

/proc/getNeighbors(turf/current, list/directions, list/passableCache)
	. = list()
	var/cardinal_bits = 0
	
	// handle cardinals straightforwardly
	for(var/direction in cardinal)
		if(direction in directions)
			var/turf/T = get_step(current, direction)
			if(T)
				var/passable = passableCache[T]
				if(isnull(passable))
					passable = checkTurfPassable(T)
					passableCache[T] = passable
				if(passable)
					. += T
					cardinal_bits |= direction

	 //diagonals need to avoid the leaking problem
	for(var/direction in ordinal)
		if(direction in directions)
			var/turf/T = get_step(current, direction)
			if(T)
				var/passable = passableCache[T]
				if(isnull(passable))
					passable = checkTurfPassable(T)
					passableCache[T] = passable
				if(passable)
					// check relevant cardinals
					var/clear = TRUE
					for(var/c_dir in cardinal)
						if(direction & c_dir)
							if(!(cardinal_bits & c_dir))
								clear = FALSE
								break
					if(clear)
						. += T

/proc/checkTurfPassable(turf/T)
	if(!T || T.density)
		return FALSE
	if(istype(T, /turf/floor/broken_floor) && !T.iscovered())
		return FALSE
	if(istype(T, /turf/floor/beach/water/deep) && !T.iscovered())
		return FALSE
	for(var/obj/O in T)
		if (O.density)
			if (istype(O, /obj/structure/simple_door))
				var/obj/structure/simple_door/D = O
				if (D.locked)
					return FALSE
				continue
			if (istype(O, /obj/covers))
				var/obj/covers/W = O
				if (W.passable == FALSE)
					return FALSE
				continue
			return FALSE
	for(var/mob/M in T)
		if (M.density && M.anchored)
			return FALSE
	return TRUE

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

/mob/living/simple_animal/hostile/human/proc/do_movement(var/atom/tgt = null)
	if (stat == 2) //dead
		moving = FALSE
		return FALSE
	if (tgt)
		// Retargeting: invalidate stale path and allow re-entry
		if(tgt != target_obj)
			found_path = list()
		target_obj = tgt
	if (!target_obj)
		found_path = list()
		moving = FALSE
		return FALSE
	if (get_dist(src, target_obj) <= 1)
		// Clear pathfind_target if we're moving to it
		if (target_obj == pathfind_target)
			pathfind_target = null
		target_obj = null
		found_path = list()
		moving = FALSE
		return FALSE

	// Loop protection: block external re-entry when a loop is already running.
	// We release the lock (moving = FALSE) before each spawn() so the next
	// iteration of THIS loop is not blocked by the guard.
	if(moving && !tgt)
		return TRUE
	moving = TRUE

	// Stuck detection
	if (loc == last_loc)
		stuck_ticks++
	else
		stuck_ticks = 0
		last_loc = loc

	// If stuck for several ticks, try to recover
	if (stuck_ticks >= 6 && destroy_surroundings)
		DestroySurroundings()
		stuck_ticks = 0
	else if (stuck_ticks >= 4)
		// Clear path so it recalculates on next iteration (fall through)
		found_path = list()

	// Check if path is stale (target moved too far from path's end)
	if(found_path.len > 0)
		var/turf/path_end = found_path[found_path.len]
		if(get_dist(path_end, get_turf(target_obj)) > 2)
			found_path = list()

	if(found_path.len > 0)
		var/turf/next = found_path[1]

		// If we reached the next node, remove it
		if(loc == next)
			found_path.Cut(1, 2)
			if(found_path.len >= 1)
				next = found_path[1]
			else
				next = get_turf(target_obj)
		// If we are too far from the path, it's invalid – recalculate
		else if(get_dist(src, next) > 1)
			found_path = list()
			moving = FALSE
			spawn(1)
				do_movement()
			return FALSE

		if(next)
			var/move_dir = get_dir(src, next)
			if(move_dir)
				if(!step(src, move_dir))
					// Stuck on an obstacle – try perpendicular directions first
					if (stuck_ticks < 3)
						var/side_dir = pick(turn(move_dir, 90), turn(move_dir, -90))
						if (!step(src, side_dir))
							step(src, turn(side_dir, 180))
					else
						DestroySurroundings()

		moving = FALSE
		spawn(move_to_delay)
			do_movement()
		return found_path.len
	else
		// No cached path – calculate one
		found_path = list()
		if (get_path())
			moving = FALSE
			spawn(move_to_delay)
				do_movement()
			return found_path.len
		else
			// Fallback: step_towards handles bumping natively
			if(!step_towards(src, target_obj))
				// Stuck on an obstacle – try perpendicular directions
				if (stuck_ticks < 3)
					var/dir_to_target = get_dir(src, target_obj)
					var/side_dir = pick(turn(dir_to_target, 90), turn(dir_to_target, -90))
					if (!step(src, side_dir))
						step(src, turn(side_dir, 180))
				else
					DestroySurroundings()
			moving = FALSE
			spawn(move_to_delay)
				do_movement()
			return FALSE

/mob/living/simple_animal/hostile/human/proc/get_path(var/atom/tgt = null)
	if (tgt)
		target_obj = tgt
	if(!target_obj)
		return FALSE

	// Pathfinding rate limiting
	if(world.time < last_pathfound + 10)
		return FALSE
	last_pathfound = world.time

	var/turf/ta = get_turf(src)
	var/turf/tb = get_turf(target_obj)
	if (!ta || !tb)
		return FALSE
	found_path = cirrAstar(ta, tb, 1, 250)
	if(!found_path || !found_path.len) // no path
		return FALSE
	return found_path.len