// Isolated native geometry; production corner/overlay constructors are extracted.
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 32
	maxz = 4
	turf = /turf/test
	area = /area/test
	tick_lag = 1
var/probe_startup = FALSE
var/probe_overlays_ready = FALSE
var/probe_early = 0
var/probe_pauses = 0
var/probe_premature = 0
var/probe_errors = 0
var/probe_identity = 0
var/probe_activity_calls = 0
var/probe_new_callbacks = 0
var/probe_build_waiters = 0
var/probe_replacement_started = FALSE
var/probe_concurrent_scenario = FALSE
var/probe_inject_error = FALSE
var/probe_failure_waiter_done = FALSE
var/probe_clear_waiter_done = FALSE
var/probe_activity_waiter_done = FALSE
var/probe_activity_waiters = 0
var/probe_owner_activations = 0
var/probe_owner_duplicates = 0
var/list/probe_activated_corners = list()
var/probe_failure_release = TRUE
var/probe_prestartup_contract = TRUE
var/list/probe_overlay_order = list()
var/list/probe_bulk_overlay_order = list()
var/list/probe_compatibility_overlay_order = list()
var/list/probe_expected_compatibility_order = list()
var/list/probe_snapshots = list()
var/time_of_day
var/datum/test_map/map = new
var/datum/test_ticker/ticker = new
var/list/lighting_overlay_list = list()
/datum/test_map
	var/list/zlevels_without_lighting = list(3,4)
/datum/test_ticker
	var/current_state = 0
/area
	var/dynamic_lighting = TRUE
	var/is_void_area = FALSE
/area/test
/turf
	var/has_opaque_atom = FALSE
	var/list/corners = list(null,null,null,null)
	var/atom/movable/lighting_overlay/lighting_overlay
/turf/test
/turf/test/replacement
/turf/wall
	var/list/damage_overlays = list()
/turf/wall/rockwall
/turf/wall/indestructable
/atom/movable/lighting_overlay
	var/needs_update = FALSE
	var/probe_render_calls = 0
/atom/movable/lighting_overlay/proc/update_overlay()
	probe_render_calls++
	return
/datum/light_source/proc/recalc_corner(datum/lighting_corner/C)
	return
/proc/probe_pool(path, turf/T, defer = FALSE)
	var/result = new path(T,defer)
	if (probe_concurrent_scenario && probe_startup && !probe_replacement_started)
		probe_replacement_started = TRUE
		spawn()
			// Revisit a position already passed by the overlay sweep. Native turf
			// refs retarget; preserve corners exactly as ChangeTurf does.
			var/turf/old = locate(1,1,1)
			var/list/saved_corners = old.corners
			if (old.lighting_overlay)
				del(old.lighting_overlay)
			var/turf/replacement = new /turf/test/replacement(old)
			replacement.corners = saved_corners
		spawn()
			var/turf/activity_turf = locate(2,2,1)
			var/datum/lighting_corner/C = activity_turf.corners[1]
			if (lighting_startup_in_progress)
				probe_activity_waiters++
			C.update_active()
			probe_activity_waiter_done = TRUE
	return result
/proc/probe_reverse(list/L)
	for (var/i = 1, i <= L.len / 2, i++)
		L.Swap(i, L.len - i + 1)
	return L
/proc/get_area(atom/A)
	return A.loc
/proc/qdel(atom/A)
	del(A)
/proc/qdel_list(list/L)
	L.Cut()
/proc/pick_TOD()
	return "Midday"
/proc/coord(turf/T)
	return "[T.x],[T.y],[T.z]"
/proc/environment_sweep_pause(work)
	if (probe_inject_error)
		probe_inject_error = FALSE
		spawn()
			var/turf/build_turf = locate(1,1,1)
			build_turf.lighting_build_overlay()
			probe_failure_waiter_done = TRUE
		spawn()
			var/turf/clear_turf = locate(2,2,1)
			clear_turf.lighting_clear_overlay()
			probe_clear_waiter_done = TRUE
		sleep(1)
		throw new /exception("deliberate startup interruption")
	if (work >= 64 || world.tick_usage >= 20)
		probe_pauses++
		if (probe_startup && (lighting_corners_initialised || created_lighting_corners_and_overlays))
			probe_premature++
		sleep(world.tick_lag)
		return TRUE
	return FALSE
/proc/probe_snapshot(label)
	var/list/rows = list()
	for (var/turf/T in world)
		var/area/test/A = get_area(T)
		if (!map.zlevels_without_lighting.Find(T.z) && A.dynamic_lighting && !istype(T,/turf/wall/rockwall) && !istype(T,/turf/wall/indestructable))
			var/overlay_count = 0
			for (var/atom/movable/lighting_overlay/O in T)
				overlay_count++
			// The standalone-only level has corners but intentionally no overlays.
			if (T.z != 4 && (overlay_count != 1 || !T.lighting_overlay))
				probe_identity++
			for (var/j = 1 to 4)
				if (!T.corners[j])
					probe_identity++
		var/list/slots = list()
		for (var/i = 1 to 4)
			var/datum/lighting_corner/C = T.corners[i]
			if (!C)
				slots += "none"
				continue
			var/list/masters = list()
			var/expected_active = FALSE
			for (var/turf/M in C.masters)
				masters += "[coord(M)]:[C.masters[M]]"
				var/opposite = LIGHTING_CORNER_DIAGONAL.Find(turn(C.masters[M],180))
				if (M.corners[opposite] != C)
					probe_identity++
				if (M.lighting_overlay)
					expected_active = TRUE
			if (C.active != expected_active)
				probe_identity++
			slots += "[C.x],[C.y]:[C.active]:[jointext(masters,";")]"
		var/queued = !!lighting_overlay_list.Find(T.lighting_overlay)
		var/render_calls = T.lighting_overlay ? T.lighting_overlay.probe_render_calls : 0
		if (probe_expected_compatibility_order.Find(coord(T)) && (!queued || render_calls != 1))
			probe_identity++
		rows += "[coord(T)]:[T.type]:[!!T.lighting_overlay]:[queued]:[render_calls]:[jointext(slots,"|")]"
	probe_snapshots[label] = rows
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Error(exception/E)
	probe_errors++
	world.log << "runtime error: [E]"
	return
/world/New()
	OpenPort("none")
	spawn()
		if (world.port || OpenPort(0) || world.port)
			world.log << "PORT_OPEN"
			del(world)
			return
		new /turf/wall/rockwall(locate(8,8,1))
		new /turf/wall/indestructable(locate(12,12,1))
		var/area/test/void_area = new
		void_area.is_void_area = TRUE
		void_area.contents += locate(12,12,1)
		var/area/test/dark_area = new
		dark_area.dynamic_lighting = FALSE
		dark_area.contents += locate(20,20,1)
		var/area/test/standalone_area = new
		standalone_area.dynamic_lighting = FALSE
		for (var/turf/T in block(locate(1,1,4),locate(world.maxx,world.maxy,4)))
			standalone_area.contents += T
		// Expected default-constructor sites, recorded in native world traversal order.
		for (var/turf/compatibility_turf in world)
			var/area/compatibility_area = get_area(compatibility_turf)
			if (compatibility_area.dynamic_lighting && (map.zlevels_without_lighting.Find(compatibility_turf.z) || (compatibility_area.is_void_area && istype(compatibility_turf,/turf/wall/indestructable))))
				probe_expected_compatibility_order += coord(compatibility_turf)
		probe_startup = TRUE
		create_lighting()
		probe_startup = FALSE
		sleep(2)
		sleep(8)
		probe_snapshot("initial")
		probe_overlays_ready = FALSE
		probe_startup = TRUE
		create_lighting()
		probe_startup = FALSE
		sleep(2)
		probe_snapshot("repeat")
		// Ordinary constructors still defer activity instead of running inline.
		var/datum/lighting_corner/runtime_corner = new(locate(1,1,1), SOUTHWEST)
		if (runtime_corner.active)
			probe_identity++
		sleep(2)
		if (!runtime_corner.active)
			probe_identity++
		probe_snapshot("runtime")
		// Existing standalone entry points retain default constructor scheduling.
		map.zlevels_without_lighting = list(3)
		standalone_area.dynamic_lighting = TRUE
		var/activity_before = probe_activity_calls
		create_lighting_corners_zlevel(4)
		create_all_lighting_corners()
		sleep(2)
		if (probe_activity_calls <= activity_before)
			probe_identity++
		probe_snapshot("standalone")
		// Freeze equal-workload observations before the candidate-only race case.
		var/list/parity_snapshots = probe_snapshots.Copy()
		var/list/parity_overlay_order = probe_overlay_order.Copy()
		var/list/parity_bulk_order = probe_bulk_overlay_order.Copy()
		var/list/parity_compatibility_order = probe_compatibility_overlay_order.Copy()
		var/list/concurrent_snapshot = list()
		var/list/concurrent_overlay_order = list()
		#ifdef PROBE_CANDIDATE
		// Force a new overlay at an already visited position during a bounded pass.
		var/concurrent_order_start = probe_overlay_order.len + 1
		var/turf/concurrent_turf = locate(1,1,1)
		del(concurrent_turf.lighting_overlay)
		probe_concurrent_scenario = TRUE
		probe_overlays_ready = FALSE
		probe_startup = TRUE
		create_lighting()
		probe_startup = FALSE
		sleep(8)
		probe_concurrent_scenario = FALSE
		probe_snapshot("concurrent")
		concurrent_snapshot = probe_snapshots["concurrent"]
		concurrent_overlay_order = probe_overlay_order.Copy(concurrent_order_start)
		if (!probe_replacement_started || !istype(locate(1,1,1), /turf/test/replacement))
			probe_identity++
		var/turf/failure_turf = locate(2,2,1)
		var/datum/lighting_corner/failure_corner = failure_turf.corners[1]
		failure_corner.active = FALSE
		probe_inject_error = TRUE
		var/caught = FALSE
		try
			create_lighting()
		catch (var/exception/E)
			// Only the injected pause failure proves the cleanup path was exercised.
			caught = E.name == "deliberate startup interruption"
		sleep(2)
		probe_failure_release = caught && !failure_corner.active && probe_failure_waiter_done && probe_clear_waiter_done && !lighting_startup_in_progress && !lighting_corners_initialised && !created_lighting_corners_and_overlays
		// Both direct APIs still work when startup has never begun (or is idle).
		var/turf/prestartup_turf = locate(40,32,4)
		var/datum/lighting_corner/prestartup_corner = new(prestartup_turf,NORTHEAST)
		prestartup_turf.corners[1] = prestartup_corner
		prestartup_turf.lighting_build_overlay()
		sleep(2)
		probe_prestartup_contract = !!prestartup_turf.lighting_overlay && prestartup_corner.active
		#endif
		text2file(json_encode(list("snapshots"=parity_snapshots,"overlay_order"=parity_overlay_order,"bulk_overlay_order"=parity_bulk_order,"compatibility_overlay_order"=parity_compatibility_order,"expected_compatibility_order"=probe_expected_compatibility_order,"order_scope"="strict bulk parity; candidate compatibility native world traversal; candidate race isolated","concurrent_snapshot"=concurrent_snapshot,"concurrent_overlay_order"=concurrent_overlay_order,"replacement_started"=probe_replacement_started,"early_activations"=probe_early,"identity_failures"=probe_identity,"pauses"=probe_pauses,"premature_flags"=probe_premature,"new_callbacks"=probe_new_callbacks,"build_waiters"=probe_build_waiters,"prestartup_contract"=probe_prestartup_contract,"activity_waiter_done"=probe_activity_waiter_done,"activity_waiters"=probe_activity_waiters,"owner_activations"=probe_owner_activations,"owner_duplicates"=probe_owner_duplicates,"failure_release"=probe_failure_release,"port_closed"=!world.port,"runtime_errors"=probe_errors,"native_loop_checks"=world.loop_checks)),"result.json")
		del(world)
		return
