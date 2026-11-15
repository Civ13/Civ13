// Headless probe for click-to-move routing (code/modules/1713/click_route.dm):
// the planner goes round walls without cutting corners, prefers dry ground
// over wading, never enters deep water, stops next to a goal it can't stand
// on, refuses far or sealed goals, and a route stops when the walker is hurt
// or cancelled. Run: python3 tests/ecology_spawning/run_linux.py . tests/click_route/probe.dm
/world
	maxx = 60
	maxy = 30
	maxz = 1
	turf = /turf/floor/dirt

/obj/map_metadata/click_route_probe/New()
	map = src

var/click_route_failures = 0
var/click_route_runtime_error = FALSE
/proc/click_route_check(condition, label)
	if (!condition)
		click_route_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/world/Error(exception/e)
	click_route_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/click_route_probe
		makeDatumRefLists()
		click_route_probe_run()
	catch(var/exception/e)
		click_route_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = click_route_failures, "runtime_error" = click_route_runtime_error, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/click_route_set(x1, y1, x2, y2, turf_type)
	for (var/turf/T in block(locate(x1, y1, 1), locate(x2, y2, 1)))
		T.ChangeTurf(turf_type)

// Each step is one tile, never into a dense tile, and a diagonal step has
// both sides open.
/proc/click_route_path_ok(list/path, turf/start)
	var/turf/prev = start
	for (var/turf/T in path)
		if (get_dist(prev, T) != 1 || T.density)
			return FALSE
		if (prev.x != T.x && prev.y != T.y)
			var/turf/side1 = locate(T.x, prev.y, 1)
			var/turf/side2 = locate(prev.x, T.y, 1)
			if (side1.density || side2.density)
				return FALSE
		prev = T
	return TRUE

/proc/click_route_path_has(list/path, turf_type)
	for (var/turf/T in path)
		if (istype(T, turf_type))
			return TRUE
	return FALSE

/proc/click_route_probe_run()
	var/mob/living/human/H = new(locate(3, 10, 1))
	H.next_calculate_tally = -1
	H.nutrition = H.max_nutrition
	H.water = H.max_water

	// Round a wall.
	click_route_set(10, 4, 10, 16, /turf/wall/rockwall)
	var/list/path = click_route_plan(H, get_turf(H), locate(16, 10, 1))
	click_route_check(islist(path) && path.len && path[path.len] == locate(16, 10, 1), "reaches a goal behind a wall")
	click_route_check(islist(path) && click_route_path_ok(path, get_turf(H)), "walks round the wall without cutting corners")
	click_route_check(islist(path) && path.len <= 20, "the way round is short ([islist(path) ? path.len : path])")

	// A goal in the wall: stop beside it.
	path = click_route_plan(H, get_turf(H), locate(10, 10, 1))
	click_route_check(islist(path) && path.len && get_dist(path[path.len], locate(10, 10, 1)) == 1, "stops next to a wall it was sent into")

	// No corner cutting: walls on two sides of a diagonal.
	click_route_set(4, 10, 4, 10, /turf/wall/rockwall)
	click_route_set(3, 11, 3, 11, /turf/wall/rockwall)
	path = click_route_plan(H, get_turf(H), locate(4, 11, 1))
	click_route_check(islist(path) && path.len > 1 && click_route_path_ok(path, get_turf(H)), "does not squeeze between diagonal walls ([islist(path) ? path.len : path])")
	click_route_set(4, 10, 4, 10, /turf/floor/dirt)
	click_route_set(3, 11, 3, 11, /turf/floor/dirt)

	// Prefer dry ground over wading when the detour is short.
	H.loc = locate(20, 10, 1)
	click_route_set(22, 10, 28, 10, /turf/floor/beach/water/shallowsaltwater)
	path = click_route_plan(H, get_turf(H), locate(30, 10, 1))
	click_route_check(islist(path) && !click_route_path_has(path, /turf/floor/beach/water), "walks round a short strip of shallow water")
	// A wide lake is waded straight across rather than walked round for ages.
	click_route_set(22, 1, 28, 30, /turf/floor/beach/water/shallowsaltwater)
	path = click_route_plan(H, get_turf(H), locate(30, 10, 1))
	click_route_check(islist(path) && path.len && click_route_path_has(path, /turf/floor/beach/water), "wades across water that has no way round")
	// Deep water is never planned through.
	click_route_set(22, 1, 28, 30, /turf/floor/beach/water/deep/saltwater)
	path = click_route_plan(H, get_turf(H), locate(30, 10, 1))
	click_route_check(istext(path), "deep water with no way round has no route ([path])")
	click_route_set(22, 1, 28, 30, /turf/floor/dirt)

	// Too far, other levels and sealed rooms are refused with a reason.
	path = click_route_plan(H, get_turf(H), locate(59, 10, 1))
	click_route_check(istext(path) && findtext(path, "too far"), "a far goal is refused ([path])")
	click_route_set(40, 10, 44, 14, /turf/wall/rockwall)
	click_route_set(42, 12, 42, 12, /turf/floor/dirt)
	path = click_route_plan(H, get_turf(H), locate(42, 12, 1))
	click_route_check(istext(path) && findtext(path, "no way"), "a sealed room is refused ([path])")
	path = click_route_plan(H, get_turf(H), get_turf(H))
	click_route_check(islist(path) && !path.len, "the spot you stand on needs no route")

	// Agents walk the route tile by tile until it arrives.
	H.loc = locate(3, 10, 1)
	var/turf/goal = locate(16, 10, 1)
	path = click_route_plan(H, get_turf(H), goal)
	var/datum/click_route/R = new(H, goal, path, TRUE)
	H.click_route = R
	for (var/i in 1 to 60)
		var/d = R.agent_next_dir()
		if (!d)
			break
		H.loc = get_step(H, d)
	click_route_check(R.done && R.arrived && get_turf(H) == goal && H.click_route_last == "arrived", "an agent route arrives ([R.result])")
	click_route_check(isnull(H.click_route), "an arrived route lets go of the walker")

	// A walker who is hurt stops.
	H.loc = locate(3, 10, 1)
	path = click_route_plan(H, get_turf(H), goal)
	R = new(H, goal, path, TRUE)
	H.click_route = R
	R.agent_next_dir()
	H.adjustBruteLoss(10)
	H.updatehealth()
	click_route_check(!R.agent_next_dir() && R.done && !R.arrived && findtext(R.result, "hurt"), "a hurt walker stops ([R.result])")
	H.revive()

	// A hostile animal coming close stops the route.
	H.loc = locate(3, 10, 1)
	path = click_route_plan(H, get_turf(H), goal)
	R = new(H, goal, path, TRUE)
	H.click_route = R
	R.agent_next_dir()
	var/mob/living/simple_animal/A = new(locate(5, 12, 1))
	A.behaviour = "hostile"
	click_route_check(!R.agent_next_dir() && R.done && findtext(R.result, "close"), "a hostile animal close by stops the route ([R.result])")
	qdel(A)

	// Cancelling (a movement key) clears the axes the route was holding.
	path = click_route_plan(H, get_turf(H), goal)
	R = new(H, goal, path, FALSE)
	H.click_route = R
	R.owns_axes = TRUE
	H.movement_eastwest = EAST
	H.movement_northsouth = NORTH
	H.click_route_cancel("manual")
	click_route_check(isnull(H.click_route) && isnull(H.movement_eastwest) && isnull(H.movement_northsouth) && R.done && !R.arrived, "cancelling lets go of the held axes")
