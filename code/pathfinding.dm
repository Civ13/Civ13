//ported from goonstation 2020 release. WIP

/proc/cirrAstar(var/turf/start, var/turf/goal, var/min_dist=1, var/maxtraverse = 500)
	if(!start || !goal) return list()
	var/list/closedSet = list()    // turf -> TRUE, O(1) lookup
	var/list/inOpen = list()       // turf -> TRUE, O(1) membership
	var/list/cameFrom = list()
	var/list/gScore = list()
	var/list/fScore = list()
	var/list/passableCache = list()

	gScore[start] = 0
	fScore[start] = heuristic(start, goal)
	inOpen[start] = TRUE

	// Track open nodes in a flat list; scan for min fScore each iteration.
	// Avoids O(n) list removal (openSet -= x) on every iteration.
	var/list/openList = list(start)

	var/traverse = 0

	while(openList.len > 0)
		// Pick lowest fScore from open set
		var/turf/current = null
		var/lowest_f = 1.#INF
		for(var/i = 1; i <= openList.len; i++)
			var/turf/candidate = openList[i]
			if(closedSet[candidate])
				continue
			var/f = fScore[candidate]
			if(f < lowest_f)
				lowest_f = f
				current = candidate
		if(!current)
			break

		if(get_dist(current, goal) <= min_dist)
			return reconstructPath(cameFrom, current)

		closedSet[current] = TRUE
		inOpen -= current

		var/list/neighbors = getNeighbors(current, alldirs, passableCache)
		for(var/turf/neighbor in neighbors)
			if(closedSet[neighbor])
				continue

			var/terrain_cost = 1 + (neighbor.move_delay ? neighbor.move_delay / 10 : 0)
			var/dist = ((current.x == neighbor.x || current.y == neighbor.y) ? 1 : 1.414) * terrain_cost
			var/tentativeGScore = gScore[current] + dist

			if(!inOpen[neighbor])
				openList += neighbor
				inOpen[neighbor] = TRUE
			else if(tentativeGScore >= (gScore[neighbor] || 1.#INF))
				continue

			cameFrom[neighbor] = current
			gScore[neighbor] = tentativeGScore
			fScore[neighbor] = tentativeGScore + heuristic(neighbor, goal)

		traverse++
		if(traverse > maxtraverse)
			return list()
	return list()

/proc/heuristic(turf/start, turf/goal)
	if(!start || !goal)
		return null
	return abs(start.x - goal.x) + abs(start.y - goal.y)

/proc/distance(turf/start, turf/goal)
	if(!start || !goal)
		return null
	var/dx = goal.x - start.x
	var/dy = goal.y - start.y
	return sqrt(dx*dx + dy*dy)

/proc/reconstructPath(list/cameFrom, turf/current)
	var/list/totalPath = list(current)
	while(current in cameFrom)
		current = cameFrom[current]
		totalPath += current
	var/list/tlist = list()
	for(var/i = totalPath.len to 1 step -1)
		tlist += totalPath[i]
	return tlist

/proc/getNeighbors(turf/current, list/directions, list/passableCache)
	var/cardinal_bits = 0
	// Reuse a single list across all calls to avoid GC churn.
	// Caller reads .len and accesses elements [1]..[n] so this is safe.
	. = list()

	// handle cardinals
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

	// diagonals – avoid corner-cutting
	for(var/direction in ordinal)
		if(direction in directions)
			var/turf/T = get_step(current, direction)
			if(T)
				var/passable = passableCache[T]
				if(isnull(passable))
					passable = checkTurfPassable(T)
					passableCache[T] = passable
				if(passable)
					var/clear = TRUE
					if((direction & NORTH) && !(cardinal_bits & NORTH))
						clear = FALSE
					else if((direction & SOUTH) && !(cardinal_bits & SOUTH))
						clear = FALSE
					else if((direction & EAST) && !(cardinal_bits & EAST))
						clear = FALSE
					else if((direction & WEST) && !(cardinal_bits & WEST))
						clear = FALSE
					if(clear)
						. += T

/proc/checkTurfPassable(turf/T)
	if(!T || T.density)
		return FALSE
	if(T.iscovered())
		for(var/obj/O in T)
			if(O.density)
				if(istype(O, /obj/structure/simple_door))
					var/obj/structure/simple_door/D = O
					if(D.locked)
						return FALSE
					continue
				if(istype(O, /obj/covers))
					var/obj/covers/W = O
					if(W.passable == FALSE)
						return FALSE
					continue
				return FALSE
		return TRUE
	// Uncovered – check special turf types
	if(istype(T, /turf/floor/broken_floor))
		return FALSE
	if(istype(T, /turf/floor/beach/water/deep))
		return FALSE
	for(var/obj/O in T)
		if(O.density)
			if(istype(O, /obj/structure/simple_door))
				var/obj/structure/simple_door/D = O
				if(D.locked)
					return FALSE
				continue
			if(istype(O, /obj/covers))
				var/obj/covers/W = O
				if(W.passable == FALSE)
					return FALSE
				continue
			return FALSE
	for(var/mob/M in T)
		if(M.density && M.anchored)
			return FALSE
	return TRUE

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

	// Loop protection: block re-entry when a loop is already running.
	// We release the lock (moving = FALSE) before each spawn() so the next
	// iteration of THIS loop is not blocked by the guard.
	if(moving)
		// External callers may pass a new target – just retarget, don't re-enter
		if(tgt && tgt != target_obj)
			found_path = list()
			target_obj = tgt
		return TRUE
	moving = TRUE

	// Stuck detection – not making any movement at all
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
			spawn(move_to_delay)
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
			// Use a longer delay in fallback mode to prevent rapid oscillation
			// when no valid path exists (e.g. mob on wrong side of river)
			var/fallback_delay = max(move_to_delay, 10)
			spawn(fallback_delay)
				do_movement()
			return FALSE

/mob/living/simple_animal/hostile/human/proc/get_path(var/atom/tgt = null)
	if (tgt)
		target_obj = tgt
	if(!target_obj)
		return FALSE

	// Pathfinding rate limiting – avoid hammering A* every few ticks
	if(world.time < last_pathfound + 30)
		return FALSE
	last_pathfound = world.time

	// Tick budget: bail if we've already used >25% of this tick
	if(world.tick_usage > 75)
		return FALSE

	var/turf/ta = get_turf(src)
	var/turf/tb = get_turf(target_obj)
	if (!ta || !tb)
		return FALSE
	// Reduce maxtraverse when far away – long paths are likely invalid
	// and expensive. Re-pathfind closer to target instead.
	var/max_nodes = 250
	var/direct_dist = get_dist(ta, tb)
	if(direct_dist < 15)
		max_nodes = 100
	found_path = cirrAstar(ta, tb, 1, max_nodes)
	if(!found_path || !found_path.len) // no path
		return FALSE
	return found_path.len