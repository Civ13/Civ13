// Click-to-move routing. A player Ctrl+clicks a spot that is not something
// next to them (Ctrl+click on an adjacent thing still pulls it) and walks
// there along the quickest route. Agent characters use the same planner
// through the walk_to queue action (agent_movement.dm).
//
// The planner is a bounded A* over tiles. A step costs what Check Movement
// (movement_check.dm) says it costs: the character's walking or running pace,
// the ground (snow, mud, flood, wading) and the hill, so roads and floors win
// over mud and climbs. It never plans through walls, closed locked doors,
// lava, deep water, open air or fire, and it never cuts a corner diagonally.
//
// A player's route steers the same held-key axes the movement keys set, so
// free movement, running, pulling and every movement rule stay exactly as
// when walking by hand. It stops on arrival, on any movement key, when the
// character is hurt or a hostile animal comes close, and when the way stays
// blocked after a few new plans.
//
// tests/click_route/probe.dm checks the planner and the stop rules.

#define CLICK_ROUTE_MAX_RANGE 32
#define CLICK_ROUTE_MAX_EXPANSIONS 2500
#define CLICK_ROUTE_MARGIN 8
#define CLICK_ROUTE_STUCK_TIME 20
#define CLICK_ROUTE_MAX_REPLANS 3
#define CLICK_ROUTE_DANGER_RANGE 5
#define CLICK_ROUTE_CHECK_EVERY 5

/mob/var/tmp/datum/click_route/click_route = null

// A walk in progress belongs to this process: a saved route comes back
// without its mover and goal, and building it stops the load.
/mob/persistence_runtime_var(key)
	return key == "click_route" || ..(key)

// ---------------------------------------------------------------- planning

// Ground the character would not step onto on purpose.
/proc/click_route_hazard_turf(turf/T)
	if (istype(T, /turf/floor/lava) || istype(T, /turf/floor/beach/water/deep) || istype(T, /turf/floor/broken_floor))
		return TRUE
	if (locate(/obj/effect/fire) in T)
		return TRUE
	return FALSE

// Whether M could step from A onto the neighbouring tile B, by the rules
// turf/Enter applies, without moving anything or bumping into it.
/proc/click_route_can_step(mob/living/M, turf/A, turf/B)
	if (!A || !B || A.z != B.z || B.density)
		return FALSE
	if (click_route_hazard_turf(B))
		return FALSE
	if (!B.CanPass(M, B))
		return FALSE
	var/d = get_dir(A, B)
	for (var/obj/O in A)
		if (O != M && !O.CheckExit(M, B, d))
			return FALSE
	for (var/atom/movable/O in B)
		if (O == M || O == M.pulling)
			continue
		if (ismob(O))
			continue // people and animals move or swap; they only cost time
		if (istype(O, /obj/structure/simple_door))
			var/obj/structure/simple_door/D = O
			if (D.density && D.locked)
				return FALSE
			continue // a closed door opens when walked into
		if (!O.CanPass(M, A, TRUE, FALSE))
			return FALSE
	return TRUE

// The pace one flat step takes for M, in deciseconds, before the ground.
/proc/click_route_base_step(mob/living/M)
	if (ishuman(M))
		var/mob/living/human/H = M
		var/mult = H.movement_check_intent_mult() || 1
		return max(1, H.movement_check_unloaded_run_delay() * mult + H.movement_delay())
	return max(1, M.movement_delay() + 1)

// The extra time the ground of T adds to a step (Check Movement's ground parts).
/proc/click_route_ground_cost(mob/living/M, turf/T)
	. = 0
	if (ishuman(M))
		var/mob/living/human/H = M
		var/list/parts = H.movement_check_ground_parts(T)
		for (var/label in parts)
			. += parts[label]
	else
		var/turf/floor/F = T
		if (istype(F))
			. += F.move_delay
	for (var/obj/structure/barbwire/W in T)
		. += 40 // cuts the legs: only when there is no other way
		break
	for (var/obj/structure/simple_door/D in T)
		if (D.density)
			. += 6 // opening it takes a moment
		break
	for (var/mob/living/L in T)
		if (L != M && L.stat != DEAD)
			. += 4 // someone standing there
			break

// The time one step from A onto B takes, ground and hill included.
/proc/click_route_step_cost(mob/living/M, turf/A, turf/B, base, ground)
	var/cost = base + ground
	var/levels = terrain_step_levels(A, B)
	if (levels)
		cost *= terrain_grade_factor(levels, B.terrain_packed())
	if (A.x != B.x && A.y != B.y)
		cost *= ROOT2_FAST
	return cost

/proc/click_route_heuristic(turf/A, turf/B, base)
	var/dx = abs(A.x - B.x)
	var/dy = abs(A.y - B.y)
	return base * (max(dx, dy) + (ROOT2_FAST - 1) * min(dx, dy))

/proc/click_route_heap_push(list/heap, list/keys, turf/T, f)
	heap += T
	keys += f
	var/i = heap.len
	while (i > 1)
		var/parent = round(i / 2)
		if (keys[parent] <= keys[i])
			break
		heap.Swap(i, parent)
		keys.Swap(i, parent)
		i = parent

/proc/click_route_heap_pop(list/heap, list/keys)
	. = heap[1]
	var/last = heap.len
	heap.Swap(1, last)
	keys.Swap(1, last)
	heap.len--
	keys.len--
	var/n = heap.len
	var/i = 1
	while (TRUE)
		var/l = i * 2
		var/r = l + 1
		var/best = i
		if (l <= n && keys[l] < keys[best])
			best = l
		if (r <= n && keys[r] < keys[best])
			best = r
		if (best == i)
			break
		heap.Swap(i, best)
		keys.Swap(i, best)
		i = best

// Plans the quickest route for M from start to goal. Returns the tiles to
// walk, next one first (empty when already there), or a text reason when
// there is no route. When the goal itself cannot be stood on (a wall, a
// table, deep water) the route ends on a tile next to it.
/proc/click_route_plan(mob/living/M, turf/start, turf/goal)
	if (!M || !start || !goal)
		return "there is nowhere to go"
	if (start.z != goal.z)
		return "that is on another level"
	if (max(abs(start.x - goal.x), abs(start.y - goal.y)) > CLICK_ROUTE_MAX_RANGE)
		return "that is too far away to plan a route"
	var/list/targets = list()
	var/goal_standable = !goal.density && !click_route_hazard_turf(goal)
	if (goal_standable)
		for (var/atom/movable/O in goal)
			if (O != M && !ismob(O) && O.density && !istype(O, /obj/structure/simple_door) && !O.CanPass(M, goal, TRUE, FALSE))
				goal_standable = FALSE
				break
	if (goal_standable)
		targets[goal] = TRUE
	else
		for (var/d in alldirs)
			var/turf/N = get_step(goal, d)
			if (N && !N.density && !click_route_hazard_turf(N))
				targets[N] = TRUE
	if (targets[start])
		return list()
	if (!targets.len)
		return "there is no way to get there"
	var/minx = max(1, min(start.x, goal.x) - CLICK_ROUTE_MARGIN)
	var/maxx = min(world.maxx, max(start.x, goal.x) + CLICK_ROUTE_MARGIN)
	var/miny = max(1, min(start.y, goal.y) - CLICK_ROUTE_MARGIN)
	var/maxy = min(world.maxy, max(start.y, goal.y) + CLICK_ROUTE_MARGIN)
	var/base = click_route_base_step(M)
	var/list/g = list()
	var/list/parent = list()
	var/list/closed = list()
	var/list/ground = list()
	var/list/heap = list()
	var/list/keys = list()
	g[start] = 0
	click_route_heap_push(heap, keys, start, click_route_heuristic(start, goal, base))
	var/expansions = 0
	var/turf/found = null
	while (heap.len)
		var/turf/T = click_route_heap_pop(heap, keys)
		if (closed[T])
			continue
		closed[T] = TRUE
		if (targets[T])
			found = T
			break
		if (++expansions > CLICK_ROUTE_MAX_EXPANSIONS)
			break
		for (var/d in alldirs)
			var/turf/N = get_step(T, d)
			if (!N || closed[N] || N.x < minx || N.x > maxx || N.y < miny || N.y > maxy)
				continue
			if (!click_route_can_step(M, T, N))
				continue
			if (d in cornerdirs)
				// No corner cutting: both sides of the diagonal must be open.
				if (!click_route_can_step(M, T, get_step(T, d & (NORTH|SOUTH))) || !click_route_can_step(M, T, get_step(T, d & (EAST|WEST))))
					continue
			if (isnull(ground[N]))
				ground[N] = click_route_ground_cost(M, N)
			var/cost = g[T] + click_route_step_cost(M, T, N, base, ground[N])
			if (!isnull(g[N]) && g[N] <= cost)
				continue
			g[N] = cost
			parent[N] = T
			click_route_heap_push(heap, keys, N, cost + click_route_heuristic(N, goal, base))
	if (!found)
		return expansions > CLICK_ROUTE_MAX_EXPANSIONS ? "the way there is too winding to plan from here" : "there is no way to get there"
	var/list/path = list()
	var/turf/at = found
	while (at && at != start)
		path.Insert(1, at)
		at = parent[at]
	return path

// ---------------------------------------------------------------- walking

/datum/click_route
	var/mob/living/mover
	var/turf/goal
	var/list/path
	var/index = 1
	var/agent = FALSE
	var/replans = 0
	var/best_left = null
	var/last_progress = 0
	var/last_check = 0
	var/last_health = 0
	var/list/near_hostiles
	var/owns_axes = FALSE
	var/done = FALSE
	var/arrived = FALSE
	var/result = ""

/datum/click_route/New(mob/living/M, turf/T, list/route, is_agent = FALSE)
	..()
	mover = M
	goal = T
	path = route
	agent = is_agent
	last_progress = world.time
	last_check = world.time
	last_health = M.health
	near_hostiles = click_route_hostiles_near(M)

/datum/click_route/proc/left()
	return max(0, path.len - index + 1)

// Hostile animals close enough to be a danger.
/proc/click_route_hostiles_near(mob/living/M)
	. = list()
	for (var/mob/living/simple_animal/A in range(CLICK_ROUTE_DANGER_RANGE, M))
		if (A.stat != DEAD && (A.behaviour == "hostile" || A.behaviour == "hunt"))
			. += A

// Why the route must stop now, or null. Checked every CLICK_ROUTE_CHECK_EVERY.
/datum/click_route/proc/danger_reason()
	var/mob/living/M = mover
	if (M.stat != CONSCIOUS)
		return "you can't walk right now"
	if (M.restrained() || M.buckled && !istype(M.buckled, /obj/structure/bed/chair/wheelchair))
		return "you can't walk right now"
	if (M.health < last_health - 0.5)
		return "you are hurt"
	last_health = M.health
	var/list/now = click_route_hostiles_near(M)
	for (var/mob/living/simple_animal/A in now)
		if (!(A in near_hostiles))
			near_hostiles = now
			return "\the [A] is close"
	near_hostiles = now
	return null

/datum/click_route/proc/finish(reason, reached = FALSE)
	if (done)
		return
	done = TRUE
	arrived = reached
	result = reached ? "arrived" : "stopped: [reason]"
	var/mob/living/M = mover
	if (M)
		if (owns_axes)
			M.movement_northsouth = null
			M.movement_eastwest = null
			M.movement_fine = FALSE
		owns_axes = FALSE
		if (M.click_route == src)
			M.click_route = null
		M.click_route_last = result
		if (!reached && !agent && reason && M.client)
			to_chat(M, SPAN_WARNING("You stop: [reason]."))

// The way ahead is blocked: plan again from here, a few times at most.
/datum/click_route/proc/replan(why)
	if (++replans > CLICK_ROUTE_MAX_REPLANS)
		finish(why)
		return FALSE
	var/list/route = click_route_plan(mover, get_turf(mover), goal)
	if (!islist(route))
		finish(route)
		return FALSE
	path = route
	index = 1
	best_left = null
	last_progress = world.time
	return TRUE

// Players: point the held-key axes at the next tile. Called by the
// movementMachine before each held step and by every free-movement pulse.
/datum/click_route/proc/steer()
	var/mob/living/M = mover
	if (done || agent)
		return
	if (!M || QDELETED(M) || !M.client)
		finish(null)
		return
	if (world.time >= last_check + CLICK_ROUTE_CHECK_EVERY)
		last_check = world.time
		var/why = danger_reason()
		if (why)
			finish(why)
			return
	for (var/tries in 1 to 3)
		if (index > path.len)
			finish(null, TRUE)
			return
		var/turf/W = path[index]
		if (W.z != M.z)
			finish("you left the level")
			return
		var/dx = W.x * 32 - (M.x * 32 + M.step_x)
		var/dy = W.y * 32 - (M.y * 32 + M.step_y)
		// Pass through a waypoint loosely; settle on the last one.
		var/close = (index == path.len) ? 3 : 8
		if (abs(dx) <= close && abs(dy) <= close)
			index++
			best_left = null
			last_progress = world.time
			if (index <= path.len)
				var/turf/next = path[index]
				if (click_route_hazard_turf(next) && !replan("the way ahead is dangerous"))
					return
			continue
		var/dist = abs(dx) + abs(dy)
		if (isnull(best_left) || dist < best_left)
			best_left = dist
			last_progress = world.time
		else if (world.time - last_progress > CLICK_ROUTE_STUCK_TIME)
			if (!replan("the way is blocked"))
				return
			continue
		var/ns = dy > 2 ? NORTH : (dy < -2 ? SOUTH : null)
		var/ew = dx > 2 ? EAST : (dx < -2 ? WEST : null)
		if (!ns && !ew)
			// Within a pixel or two on both axes: close enough.
			index++
			continue
		M.movement_northsouth = ns
		M.movement_eastwest = ew
		M.movement_fine = FALSE
		owns_axes = TRUE
		return
	return

// Agents: the direction of the next whole-tile step, or 0 when the route
// ended (arrived or stopped; see result).
/datum/click_route/proc/agent_next_dir()
	var/mob/living/M = mover
	if (done)
		return 0
	if (!M || QDELETED(M))
		finish("gone")
		return 0
	var/why = danger_reason()
	if (why)
		finish(why)
		return 0
	var/turf/here = get_turf(M)
	while (index <= path.len && path[index] == here)
		index++
	if (index > path.len)
		finish(null, TRUE)
		return 0
	var/turf/W = path[index]
	if (get_dist(here, W) != 1 || W.z != here.z || click_route_hazard_turf(W))
		if (!replan("the way is blocked"))
			return 0
		W = path[1]
	return get_dir(here, W)

// ---------------------------------------------------------------- players

/mob/var/tmp/click_route_last = null

// Starts a player's route to A. Returns TRUE when the click was used.
/mob/proc/click_route_to(atom/A)
	return FALSE

/mob/living/click_route_to(atom/A)
	var/turf/goal = get_turf(A)
	if (!goal || !client || (!isturf(A) && !isturf(A.loc)))
		return FALSE
	if (istype(A, /obj/screen))
		return FALSE
	click_route_cancel()
	var/why = click_route_refusal()
	if (why)
		to_chat(src, SPAN_WARNING("You can't walk there: [why]."))
		return TRUE
	var/list/route = click_route_plan(src, get_turf(src), goal)
	if (!islist(route))
		to_chat(src, SPAN_WARNING("You can't walk there: [route]."))
		return TRUE
	if (!route.len)
		return TRUE
	var/list/hostiles = click_route_hostiles_near(src)
	if (hostiles.len)
		var/mob/living/simple_animal/beast = hostiles[1]
		to_chat(src, SPAN_WARNING("You can't walk there: \the [beast] is too close. Move by hand."))
		return TRUE
	click_route = new /datum/click_route(src, goal, route)
	click_route.steer()
	return TRUE

// Why this character can't follow a route right now, or null.
/mob/living/proc/click_route_refusal()
	if (stat != CONSCIOUS || !canmove)
		return "you can't move right now"
	if (restrained())
		return "you are restrained"
	if (buckled && !istype(buckled, /obj/structure/bed/chair/wheelchair))
		return "you are buckled to [buckled]"
	if (using_drone)
		return "you are flying a drone"
	if (ishuman(src))
		var/mob/living/human/H = src
		if (H.driver && H.driver_vehicle)
			return "you are driving"
		if (H.crouching)
			return "stand up first"
	return null

// Ends a route the character is following, if any.
/mob/proc/click_route_cancel(reason = null)
	if (click_route)
		var/datum/click_route/R = click_route
		R.finish(reason)

#undef CLICK_ROUTE_MAX_RANGE
#undef CLICK_ROUTE_MAX_EXPANSIONS
#undef CLICK_ROUTE_MARGIN
#undef CLICK_ROUTE_STUCK_TIME
#undef CLICK_ROUTE_MAX_REPLANS
#undef CLICK_ROUTE_DANGER_RANGE
#undef CLICK_ROUTE_CHECK_EVERY
