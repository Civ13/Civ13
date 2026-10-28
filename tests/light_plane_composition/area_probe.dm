// Production ChangeArea and turf hook are extracted verbatim by run.py.
// Overlay allocation/retirement is counted here; corner graphs, production
// area side effects and queued deletion are outside this small fixture.
var/turf/area_change_probe/area_probe_turf
var/list/area_events = list()
var/lighting_startup_in_progress = FALSE
var/created_lighting_corners_and_overlays = FALSE

/turf/var/list/corners = list()
/datum/lighting_corner
	var/active = FALSE
	var/list/affecting = list()
/datum/light_source/proc/recalc_corner(datum/lighting_corner/C)
	return
/atom/movable/lighting_overlay
/proc/probe_pool(typepath, turf/area_change_probe/T)
	T.overlay_builds++
	T.lighting_overlay = new /atom/movable/lighting_overlay(T)
	return T.lighting_overlay
/turf/proc/omit_reserved_lighting_overlay()
	return FALSE

/area
	var/location = 1

/area/area_change_probe
	var/reenter_mode = 0
	var/area/area_change_probe/reenter_destination

/area/area_change_probe/Entered(atom/A, atom/oldloc)
	if(A == area_probe_turf || istype(A, /atom/movable/area_probe_occupant))
		area_events += "[name]-entered-[isturf(A) ? "turf" : "occupant"]"
	if(istype(A, /atom/movable/area_probe_occupant) && reenter_mode)
		var/mode = reenter_mode
		reenter_mode = 0
		sleep(1)
		if(mode == 1 || mode == 2)
			ChangeArea(area_probe_turf, reenter_destination)
			if(mode == 2)
				ChangeArea(area_probe_turf, src)
		else if(mode == 3)
			new /turf/area_change_probe/replacement(area_probe_turf)
		else if(mode == 4)
			reenter_destination.contents.Add(area_probe_turf)

/area/area_change_probe/Exited(atom/A, atom/newloc)
	if(A == area_probe_turf || istype(A, /atom/movable/area_probe_occupant))
		area_events += "[name]-exited-[isturf(A) ? "turf" : "occupant"]"

/atom/movable/area_probe_occupant

/turf/area_change_probe
	var/hook_calls = 0
	var/build_calls = 0
	var/clear_calls = 0
	var/overlay_builds = 0
	var/area/hook_old
	var/area/hook_new
	var/list/hook_pairs = list()

/turf/area_change_probe/replacement

/turf/area_change_probe/change_area(area/old_area, area/new_area)
	hook_calls++
	hook_old = old_area
	hook_new = new_area
	hook_pairs += "[old_area ? old_area.name : "null"]>[new_area.name]"
	return ..()

/turf/area_change_probe/proc/reset_observations()
	window_coeff_dirty = FALSE
	hook_calls = 0
	build_calls = 0
	clear_calls = 0
	overlay_builds = 0
	hook_pairs = list()
	area_events = list()

/turf/area_change_probe/lighting_build_overlay()
	build_calls++
	return ..()

/turf/proc/lighting_clear_overlay()
	var/turf/area_change_probe/T = src
	T.clear_calls++
	if(lighting_overlay)
		qdel(lighting_overlay)
		lighting_overlay = null

/proc/check_area_changes()
	map = null
	var/turf/area_change_probe/T = locate(2,1,1)
	area_probe_turf = T
	var/area/area_change_probe/dynamic = new
	dynamic.name = "dynamic"
	var/area/area_change_probe/fullbright = new
	fullbright.name = "fullbright"
	fullbright.dynamic_lighting = FALSE
	fullbright.location = 0
	var/area/area_change_probe/indoor = new
	indoor.name = "indoor"
	indoor.location = 0
	var/area/area_change_probe/fullbright_other = new
	fullbright_other.name = "fullbright_other"
	fullbright_other.dynamic_lighting = FALSE
	fullbright_other.location = 0
	var/area/area_change_probe/dynamic_other = new
	dynamic_other.name = "dynamic_other"
	ChangeArea(T, dynamic)
	var/atom/movable/area_probe_occupant/occupant = new(T)
	if(!T.lighting_overlay)
		T.lighting_build_overlay()
	T.reset_observations()

	ChangeArea(T, fullbright)
	check(T.hook_calls == 1 && T.hook_old == dynamic && T.hook_new == fullbright, "ChangeArea dispatches turf hook")
	check(T.loc == fullbright && (T in fullbright) && !(T in dynamic), "ChangeArea native membership")
	check(occupant.loc == T, "ChangeArea retains occupant")
	check(T.window_coeff_dirty, "ChangeArea invalidates location coefficient")
	check(T.clear_calls == 1 && !T.build_calls && !T.lighting_overlay, "ChangeArea clears dynamic overlay")
	check(jointext(area_events, ",") == "dynamic-exited-turf,dynamic-exited-occupant,fullbright-entered-turf,fullbright-entered-occupant", "ChangeArea notification order")
	var/atom/movable/lighting_fullbright/F = locate() in T
	check(!!F == LIGHTING_COMPOSITION_V2, "ChangeArea fullbright coverage follows gate")

	T.reset_observations()
	ChangeArea(T, fullbright)
	check(!T.hook_calls && !T.build_calls && !T.clear_calls, "same area skips hook and overlay changes")
	check(!T.window_coeff_dirty && !area_events.len, "same area skips invalidation and notifications")
	check((locate(/atom/movable/lighting_fullbright) in T) == F, "same area retains coverage owner")

	T.reset_observations()
	ChangeArea(T, dynamic)
	check(T.loc == dynamic && !(T in fullbright), "reverse ChangeArea native membership")
	check(T.hook_calls == 1 && T.hook_old == fullbright && T.hook_new == dynamic, "reverse ChangeArea dispatch")
	check(T.window_coeff_dirty && T.build_calls == 1 && !T.clear_calls && T.lighting_overlay, "reverse ChangeArea builds overlay")
	check(!(locate(/atom/movable/lighting_fullbright) in T), "reverse ChangeArea retires coverage")
	check(jointext(area_events, ",") == "fullbright-exited-turf,fullbright-exited-occupant,dynamic-entered-turf,dynamic-entered-occupant", "reverse ChangeArea notifications")

	var/atom/movable/retained_overlay = T.lighting_overlay
	T.reset_observations()
	ChangeArea(T, indoor)
	check(T.hook_calls == 1 && T.window_coeff_dirty, "same dynamic policy still invalidates location coefficient")
	check(!T.overlay_builds && !T.clear_calls && T.lighting_overlay == retained_overlay, "same dynamic policy retains overlay")
	check(!(locate(/atom/movable/lighting_fullbright) in T), "same dynamic policy stays masked")

	T.reset_observations()
	missing_old_area = TRUE
	ChangeArea(T, fullbright)
	check(!missing_old_area && T.hook_calls == 1 && !T.hook_old && T.hook_new == fullbright, "absent old area dispatch")
	check(T.loc == fullbright && T.window_coeff_dirty, "absent old area initializes coefficient")
	check(T.clear_calls == 1 && !T.build_calls && !T.lighting_overlay, "absent old area clears overlay")
	check(jointext(area_events, ",") == "fullbright-entered-turf,fullbright-entered-occupant", "absent old area only enters")
	check(!!(locate(/atom/movable/lighting_fullbright) in T) == LIGHTING_COMPOSITION_V2, "absent old area synchronizes coverage")

	T.reset_observations()
	missing_old_area = TRUE
	ChangeArea(T, dynamic)
	check(T.hook_calls == 1 && !T.hook_old && T.hook_new == dynamic && T.window_coeff_dirty, "absent old dynamic area initializes hook")
	check(T.build_calls == 1 && !T.clear_calls && T.lighting_overlay, "absent old dynamic area builds overlay")
	check(!(locate(/atom/movable/lighting_fullbright) in T), "absent old dynamic area retires coverage")

	T.reset_observations()
	var/invalid_rejected = FALSE
	try
		ChangeArea(T, null)
	catch(var/exception/invalid_area)
		invalid_rejected = invalid_area.name == "Area change attempt failed: invalid area supplied."
	check(invalid_rejected, "invalid destination still rejected")
	check(T.loc == dynamic && !T.hook_calls && !area_events.len, "invalid destination does not mutate")

	T.reset_observations()
	fullbright.reenter_mode = 1
	fullbright.reenter_destination = indoor
	ChangeArea(T, fullbright)
	check(T.loc == indoor, "yielding notification supersedes destination")
	check(T.hook_calls == 1 && jointext(T.hook_pairs, ",") == "fullbright>indoor", "superseded transition skips outer hook")
	check(T.build_calls == 1 && !T.clear_calls && T.lighting_overlay, "superseding hook retains dynamic state")
	check(isnull(T.area_change_owner), "superseding request releases owner")

	ChangeArea(T, dynamic)
	T.reset_observations()
	fullbright.reenter_mode = 2
	ChangeArea(T, fullbright)
	check(T.loc == fullbright, "away-and-back returns to outer destination")
	check(T.hook_calls == 2 && jointext(T.hook_pairs, ",") == "fullbright>indoor,indoor>fullbright", "superseded away-and-back skips outer hook")
	check(T.build_calls == 1 && T.clear_calls == 1 && !T.lighting_overlay, "away-and-back applies only inner lighting transitions")
	check(!!(locate(/atom/movable/lighting_fullbright) in T) == LIGHTING_COMPOSITION_V2, "away-and-back retains final coverage policy")
	check(isnull(T.area_change_owner), "away-and-back releases owner")

	ChangeArea(T, dynamic)
	T.reset_observations()
	fullbright.reenter_mode = 1
	fullbright.reenter_destination = fullbright_other
	ChangeArea(T, fullbright)
	check(T.hook_calls == 1 && jointext(T.hook_pairs, ",") == "fullbright>fullbright_other", "same-fullbright supersession dispatches only inner pair")
	check(T.loc == fullbright_other && T.clear_calls == 1 && !T.lighting_overlay && !T.overlay_builds, "superseding same-fullbright policy clears actual overlay")
	check(T.window_coeff_dirty, "same-fullbright supersession invalidates coefficient")
	check(!!(locate(/atom/movable/lighting_fullbright) in T) == LIGHTING_COMPOSITION_V2, "same-fullbright supersession applies final coverage")
	check(isnull(T.area_change_owner), "same-fullbright supersession releases owner")

	ChangeArea(T, fullbright)
	T.reset_observations()
	dynamic.reenter_mode = 1
	dynamic.reenter_destination = dynamic_other
	ChangeArea(T, dynamic)
	check(T.hook_calls == 1 && jointext(T.hook_pairs, ",") == "dynamic>dynamic_other", "same-dynamic supersession dispatches only inner pair")
	check(T.loc == dynamic_other && T.overlay_builds == 1 && T.lighting_overlay && !T.clear_calls, "superseding same-dynamic policy builds missing overlay")
	check(T.window_coeff_dirty, "same-dynamic supersession invalidates coefficient")
	check(!(locate(/atom/movable/lighting_fullbright) in T), "same-dynamic supersession retires fullbright coverage")
	check(isnull(T.area_change_owner), "same-dynamic supersession releases owner")

	ChangeArea(T, fullbright)
	T.reset_observations()
	lighting_startup_in_progress = TRUE
	created_lighting_corners_and_overlays = FALSE
	var/list/waiters = list("first" = FALSE, "second" = FALSE)
	spawn(0)
		ChangeArea(T, dynamic)
		waiters["first"] = TRUE
	sleep(2)
	check(!waiters["first"] && T.loc == dynamic && !T.lighting_overlay, "real build waits for startup")
	ChangeArea(T, fullbright_other)
	lighting_startup_in_progress = FALSE
	created_lighting_corners_and_overlays = TRUE
	var/deadline = world.time + 10
	while(!waiters["first"] && world.time < deadline)
		sleep(1)
	check(waiters["first"], "startup build waiter completes")
	check(T.loc == fullbright_other && !T.lighting_overlay && !T.overlay_builds, "startup waiter reads final fullbright area before allocation")
	check(!!(locate(/atom/movable/lighting_fullbright) in T) == LIGHTING_COMPOSITION_V2, "startup waiter retains final fullbright coverage")
	check(isnull(T.area_change_owner), "startup fullbright supersession releases owner")

	ChangeArea(T, fullbright)
	T.reset_observations()
	lighting_startup_in_progress = TRUE
	created_lighting_corners_and_overlays = FALSE
	waiters["first"] = FALSE
	spawn(0)
		ChangeArea(T, dynamic)
		waiters["first"] = TRUE
	sleep(2)
	spawn(0)
		ChangeArea(T, dynamic_other)
		waiters["second"] = TRUE
	sleep(2)
	check(!waiters["first"] && !waiters["second"] && T.loc == dynamic_other && !T.lighting_overlay, "both dynamic build requests wait")
	lighting_startup_in_progress = FALSE
	created_lighting_corners_and_overlays = TRUE
	deadline = world.time + 10
	while((!waiters["first"] || !waiters["second"]) && world.time < deadline)
		sleep(1)
	check(waiters["first"] && waiters["second"], "both startup waiters complete")
	check(T.loc == dynamic_other && T.lighting_overlay && T.overlay_builds == 1, "startup dynamic waiters build one final overlay")
	check(!(locate(/atom/movable/lighting_fullbright) in T), "startup dynamic waiters retire fullbright coverage")
	check(isnull(T.area_change_owner), "startup dynamic supersession releases owner")

	ChangeArea(T, dynamic)
	T.reset_observations()
	fullbright.reenter_mode = 4
	fullbright.reenter_destination = indoor
	ChangeArea(T, fullbright)
	check(T.loc == indoor && !T.hook_calls, "direct membership change skips wrong-destination hook")
	check(isnull(T.area_change_owner), "wrong-destination request releases owner")

	T.reset_observations()
	fullbright.reenter_mode = 3
	ChangeArea(T, fullbright)
	var/turf/area_change_probe/replaced = locate(2,1,1)
	check(istype(replaced, /turf/area_change_probe/replacement), "yielding notification replaces native turf")
	check(!replaced.hook_calls && !replaced.build_calls && !replaced.clear_calls, "replacement receives no stale outer hook")
	check(isnull(replaced.area_change_owner), "replacement does not inherit request owner")
	check(occupant.loc == replaced, "native replacement retains occupant")
	check(!world.port, "ChangeArea fixture remains closed")
