// Native probe for waterwheel placement: builder on the bank, wheel in flowing water.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/river_flow/waterwheel_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/ww_probe/New()
	return
/mob/living/human/ww_probe/New()
	return
/mob/living/human/ww_probe/update_icons()
	return
var/ww_failures = 0
var/ww_runtime_error = FALSE
/proc/ww_check(condition, label)
	if (!condition)
		ww_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ww_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/ww_probe
		ww_checks()
	catch(var/exception/e)
		ww_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ww_failures, "runtime_error" = ww_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ww_checks()
	for (var/turf/T in block(locate(1, 1, 1), locate(40, 40, 1)))
		T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
	// Column 20 flows south; column 22 is still water.
	for (var/y = 1, y <= 40, y++)
		var/turf/F = locate(20, y, 1)
		F.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
		var/turf/S = locate(22, y, 1)
		S.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	var/datum/river_flow/flow = new
	flow.z_level = 1
	for (var/y = 1, y <= 40, y++)
		flow.rows += "...................s...................."
	map.river_flow_cache = flow
	map.river_flow_loaded = TRUE
	var/path = /obj/structure/civ_generator/waterwheel
	ww_check(river_current_direction(locate(20, 20, 1)) == SOUTH, "fixture column flows south")

	var/mob/living/human/ww_probe/H = new(locate(19, 20, 1))
	H.dir = EAST
	ww_check(isnull(waterwheel_build_refusal(H, path)), "builder on the bank facing flowing water may build")
	ww_check(waterwheel_build_target(H) == locate(20, 20, 1), "the wheel goes on the faced water tile")
	ww_check(isnull(waterwheel_build_refusal(H, /obj/structure/civ_generator/wind/charger)), "other generators are unaffected")
	H.dir = WEST
	ww_check(!isnull(waterwheel_build_refusal(H, path)), "facing land is refused")
	H.loc = locate(21, 20, 1)
	H.dir = EAST
	ww_check(!isnull(waterwheel_build_refusal(H, path)), "facing still water is refused")
	H.loc = locate(20, 21, 1)
	H.dir = SOUTH
	ww_check(!isnull(waterwheel_build_refusal(H, path)), "a builder standing in the water is refused")
	H.loc = locate(19, 20, 1)
	H.dir = EAST
	var/obj/structure/civ_generator/waterwheel/W = new path(locate(20, 20, 1))
	ww_check(!isnull(waterwheel_build_refusal(H, path)), "an occupied water tile is refused")
	ww_check(W.anchored && !river_carryable(W), "the wheel is anchored against the current")
	ww_check(W.rated_output() == 12, "a wheel in flowing water is rated 12")
	var/obj/structure/civ_generator/waterwheel/still = new path(locate(22, 20, 1))
	ww_check(still.rated_output() == 0, "a wheel in still water is rated 0")
	var/obj/structure/civ_generator/waterwheel/bank = new path(locate(19, 22, 1))
	ww_check(bank.rated_output() == 0, "a wheel on land is rated 0")
