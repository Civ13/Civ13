// Visible air support jets on SStimer, headless (run.py).
/world
	maxx = 200
	maxy = 200
	maxz = 1
	turf = /turf
	area = /area

var/as_failures = 0
/proc/as_check(cond, msg)
	if (!cond)
		as_failures++
	text2file("[cond ? "ok" : "FAIL"]: [msg]\n", "as_log.txt")

/world/Error(exception/e)
	as_check(FALSE, "runtime error [e] [e.file]:[e.line]")

/world/New()
	makeDatumRefLists()
	// The observation events world startup normally makes (forceMove raises moved).
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	spawn(5)
		as_run()

/proc/as_live_smoke()
	. = 0
	for (var/obj/effect/air_support_smoke/S in world)
		if (!QDELETED(S))
			.++

// Ticks after the call until the jet's track (x or y along its heading)
// first reaches mark, or -1 if it never does within limit ticks.
/proc/as_time_to(obj/effect/air_support_jet/J, axis, mark, sign, limit)
	var/started = world.time
	while (world.time - started <= limit)
		if (QDELETED(J))
			return -1
		var/turf/T = get_turf(J)
		if (T)
			var/v = axis == "x" ? T.x : T.y
			if ((v - mark) * sign >= 0)
				return world.time - started
		sleep(world.tick_lag)
	return -1

/proc/as_run()
	if (!fexists("skip_start.txt"))
		Master.start_timer_loop()
	try
		as_cases()
	catch (var/exception/e)
		as_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file("DONE\n", "as_log.txt")
	del(world)

/proc/as_cases()
	var/turf/target = locate(100, 100, 1)
	// No art, bad direction: nothing is drawn.
	as_check(isnull(air_support_jet_pass(target, "NORTH", "P-47", 10)), "a P-47 strike has no jet art and flies unseen")
	as_check(isnull(air_support_jet_pass(target, "UP", "F-16", 10)), "an unknown attack direction draws nothing")
	as_check(air_support_jet_lead(45) == 12 + 22 * 3, "lead covers the release lead plus the distance flown before release")

	// Mid-map strike heading west: launches at once from the lead point.
	var/release = 10
	var/obj/effect/air_support_jet/J = air_support_jet_pass(target, "WEST", "F-16", release)
	var/lead = air_support_jet_lead(release)
	var/turf/at = get_turf(J)
	as_check(at && at.x == target.x + lead && at.y == target.y, "the jet starts [lead] tiles behind the target on its track ([at ? "[at.x],[at.y]" : "nowhere"])")
	as_check(J.icon_state == "f16" && J.dir == WEST, "the jet draws the F-16 facing its heading ([J.icon_state], [J.dir])")
	as_check(J.plane == ROOF_PLANE && !J.mouse_opacity, "the jet flies above roofs and trees and never takes a click")
	as_check(J.shadow && get_turf(J.shadow) == at && J.shadow.plane == FLOOR_PLANE && J.shadow.icon_state == "f16", "its shadow lies on the ground under it")
	var/obj/effect/air_support_jet_shadow/shadow = J.shadow
	var/t_release = as_time_to(J, "x", target.x + AIR_SUPPORT_RELEASE_LEAD, -1, 60)
	as_check(t_release >= release - 3 && t_release <= release + 3, "it reaches the release point when the payload leaves ([t_release] ticks, wanted [release])")
	var/t_gone = 0
	while (!QDELETED(J) && t_gone < 120)
		sleep(world.tick_lag)
		t_gone += world.tick_lag
	as_check(QDELETED(J) && QDELETED(shadow), "it flies on past the target and leaves no jet or shadow behind ([t_gone] ticks)")

	// Strike heading north from the bottom edge: the launch waits.
	target = locate(60, 30, 1)
	release = 45
	J = air_support_jet_pass(target, "NORTH", "Su-25", release)
	as_check(J && J.icon_state == "su25" && J.dir == NORTH, "a Su-25 strike draws the Su-25")
	as_check(J && !J.loc && J.launch_timer, "with no room behind the target the jet waits off the map")
	var/t_over = as_time_to(J, "y", target.y, 1, 120)
	var/wanted = release + round(AIR_SUPPORT_RELEASE_LEAD / AIR_SUPPORT_JET_STEP) * AIR_SUPPORT_JET_STEP_TIME
	as_check(t_over >= wanted - 6 && t_over <= wanted + 4, "launched from the map edge it still crosses the target on time ([t_over] ticks, wanted about [wanted])")
	qdel(J)
	as_check(QDELETED(J) && (!J.shadow || QDELETED(J.shadow)), "deleting a jet mid-flight takes its shadow")

	// Rocket smoke trail: puffs along the path, then gone.
	target = locate(100, 100, 1)
	air_support_smoke_trail(target, 0, -12 * world.icon_size, 15)
	sleep(8)
	var/mid = as_live_smoke()
	as_check(mid > 0, "a rocket leaves smoke puffs along its path ([mid] at 0.8 s)")
	var/lowest = 1000
	for (var/obj/effect/air_support_smoke/S in world)
		if (!QDELETED(S))
			lowest = min(lowest, S.y)
	as_check(lowest < target.y, "the puffs sit behind the rocket on its track (lowest y [lowest])")
	sleep(40)
	as_check(as_live_smoke() == 0, "the trail fades and every puff is deleted")
