// Isolated hide washing test using real water and windlass routes. The wait
// hook counts each completed step and can alter source identity mid-action.
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/map_metadata/hide_wash_probe/New()
	map = src

/mob/living/hide_wash_worker
	var/wash_waits = 0
	var/wash_mode
	var/last_wash_message

/mob/living/hide_wash_worker/New()
	return

/mob/living/hide_wash_worker/hide_worker_connected()
	return TRUE

/mob/living/hide_wash_worker/hide_research_allowed(warn = FALSE)
	return TRUE

/mob/living/hide_wash_worker/visible_message(message, self_message, blind_message)
	last_wash_message = self_message

/mob/living/hide_wash_worker/hide_wash_wait(atom/water)
	wash_waits++
	if (wash_mode == "cancel_second" && wash_waits == 2)
		return FALSE
	if (wash_mode == "remove_fitting")
		var/obj/structure/sink/well/W = water
		qdel(W.well_fitting())
	if (wash_mode == "another_draw")
		var/obj/structure/sink/well/W = water
		W.volume = 2
	return TRUE

var/hide_wash_failures = 0
var/hide_wash_runtime_error = FALSE

/proc/hide_wash_check(condition, label)
	if (!condition)
		hide_wash_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/world/Error(exception/e)
	hide_wash_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/hide_wash_probe
		hide_wash_fitted_case("limited_volume", 2, 2, 2)
		hide_wash_fitted_case("cancel_second", 1, 7, 2)
		hide_wash_fitted_case("remove_fitting", 0, 12, 1)
		hide_wash_fitted_case("another_draw", 0, 2, 1)
		hide_wash_fitted_case("no_fitting", 0, 12, 0)
		hide_wash_shallow_case()
	catch(var/exception/e)
		hide_wash_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hide_wash_failures, "runtime_error" = hide_wash_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/hide_wash_count(atom/container, path)
	. = 0
	for (var/obj/item/stack/S in container)
		if (istype(S, path) && !QDELETED(S))
			. += S.amount

/proc/hide_wash_fitted_case(mode, expected_yield, expected_water, expected_waits)
	var/turf/stand = locate(3, 3, 1)
	var/turf/source = locate(4, 3, 1)
	var/mob/living/hide_wash_worker/U = new(stand)
	U.wash_mode = mode
	var/obj/item/stack/material/hairlesshide/H = new(U, 3, FALSE)
	U.r_hand = H
	var/obj/structure/sink/well/timber/W = new(source)
	W.volume = 12
	var/obj/structure/well_fitting/windlass/F
	if (mode == "no_fitting")
		W.attackby(H, U)
	else
		F = new(source)
		F.attackby(H, U)
	hide_wash_check(U.wash_waits == expected_waits && !H.preparing_hide, "[mode]: exact per-piece waits and action released")
	hide_wash_check(H.amount == 3 - expected_yield && W.volume == expected_water, "[mode]: source and hide are debited only for completed pieces")
	hide_wash_check(hide_wash_count(U, /obj/item/stack/material/wethide) + hide_wash_count(stand, /obj/item/stack/material/wethide) == expected_yield, "[mode]: exact wet hide yield")
	if (mode == "limited_volume")
		hide_wash_check(findtext(U.last_wash_message, "timber-lined well") && findtext(U.last_wash_message, "well windlass") && findtext(U.last_wash_message, "one at a time"), "start message names the well, windlass and per-hide pacing")
	for (var/obj/item/I in U)
		qdel(I)
	for (var/obj/item/I in stand)
		qdel(I)
	qdel(W)
	qdel(U)

/proc/hide_wash_shallow_case()
	var/turf/stand = locate(6, 6, 1)
	var/turf/source = locate(7, 6, 1)
	source.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	source = locate(7, 6, 1)
	var/mob/living/hide_wash_worker/U = new(stand)
	var/obj/item/stack/material/hairlesshide/H = new(U, 2, FALSE)
	U.r_hand = H
	hide_wash_check(H.resolve_attackby(source, U) && U.wash_waits == 2 && QDELETED(H), "ordinary shallows still wash each hide with its own wait")
	hide_wash_check(hide_wash_count(U, /obj/item/stack/material/wethide) + hide_wash_count(stand, /obj/item/stack/material/wethide) == 2, "ordinary shallows retain output accounting")

