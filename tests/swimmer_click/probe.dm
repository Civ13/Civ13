// Headless probe: a human standing in water stays in the right-click menu.
// The water mask filter hides the submerged body from the mouse, so while it
// is on the mob's mouse_opacity becomes 2 (whole tile), and goes back to 1 on
// dry ground. Run: python3 tests/ecology_spawning/run_linux.py . tests/swimmer_click/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf/floor/grass
	area = /area/caribbean
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

var/swim_failures = 0
var/swim_runtime_error = FALSE
/proc/swim_check(condition, label)
	if (!condition)
		swim_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	swim_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		makeDatumRefLists()
		if (!movementMachine)
			movementMachine = new
		swimmer_click_checks()
	catch(var/exception/e)
		swim_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = swim_failures, "runtime_error" = swim_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/swimmer_click_checks()
	var/turf/dry = locate(2, 2, 1)
	var/turf/wet = locate(3, 2, 1)
	new /turf/floor/beach/water/shallowsaltwater(wet)
	wet = locate(3, 2, 1)
	swim_check(istype(wet, /turf/floor/beach/water), "fixture: water tile")
	var/mob/living/human/H = new(dry)
	swim_check(H.mouse_opacity == 1, "dry ground: normal click area")

	H.forceMove(wet)
	H.water_overlay = TRUE
	H.update_fire(1)
	swim_check(H.filters.len, "in water: submerged body is masked")
	swim_check(H.mouse_opacity == 2, "in water: whole tile clickable, so the right-click menu lists the swimmer")
	swim_check(H.water_click_line() == 14, "saltwater shallows: waterline at chest height")
	H.update_icons()
	swim_check(H.mouse_opacity == 2, "a full redraw in water keeps the click area")

	H.forceMove(dry)
	H.water_overlay = FALSE
	H.update_fire(1)
	swim_check(!H.filters.len, "out of water: mask removed")
	swim_check(H.mouse_opacity == 1, "out of water: click area back to normal")
	swim_check(H.water_click_line() == 0, "out of water: no waterline")

	// A mob hidden from the mouse by other code stays hidden in water.
	H.mouse_opacity = 0
	H.forceMove(wet)
	H.water_overlay = TRUE
	H.update_fire(1)
	swim_check(H.mouse_opacity == 0, "an unclickable mob stays unclickable in water")
	H.water_overlay = FALSE
	H.update_fire(1)
	swim_check(H.mouse_opacity == 0, "and after leaving the water")

	// Water drawn over a bather passes clicks through to them.
	var/obj/structure/shower/bathtub/wooden/B = new(dry)
	B.add_water_overlays()
	var/top_clickable = 0
	for (var/image/I in B.overlays)
		if (I.layer > MOB_LAYER && I.mouse_opacity)
			top_clickable++
	swim_check(!top_clickable, "bathtub water over the bather does not take clicks")
