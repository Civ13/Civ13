/proc/max_lighting_z()
	. = world.maxz
	if (map)
		while (map.zlevels_without_lighting.Find(.))
			--.
	. = max(., 1)

/var/lighting_corners_initialised = FALSE
// Transient startup barrier; initial map turfs are owned by the bulk sweeps.
/var/lighting_startup_in_progress = FALSE

/proc/create_all_lighting_overlays()
	for (var/zlevel = 1 to max_lighting_z())
		create_lighting_overlays_zlevel(zlevel)

/proc/create_lighting_overlays_zlevel(var/zlevel)
	ASSERT(zlevel)
	var/work = 0

	for (var/turf/T in block(locate(1, 1, zlevel), locate(world.maxx, world.maxy, zlevel)))
		if (environment_sweep_pause(++work))
			work = 0
		if (T.supports_lighting_overlays())

			var/area/T_area = get_area(T)
			if (T_area.is_void_area)
				if (istype(T, /turf/wall/indestructable))
					var/turf/wall/W = T
					W.icon = 'icons/turf/walls.dmi'
					W.icon_state = "black"
					qdel_list(W.overlays)
					qdel_list(W.damage_overlays)
					continue

			PoolOrNew(/atom/movable/lighting_overlay, T, TRUE)

// Initial turf New historically filled sites excluded by the bulk overlay sweep.
// Preserve its dynamic-area/default-constructor behavior without per-turf waits.
/proc/create_startup_compatibility_overlays()
	var/work = 0
	for (var/turf/T in world)
		if (!T.lighting_overlay)
			var/area/A = get_area(T)
			if (A && A.dynamic_lighting)
				PoolOrNew(/atom/movable/lighting_overlay, T)
		if (environment_sweep_pause(++work))
			work = 0

// Startup defers activity until all overlays exist. Standalone callers retain
// ordinary constructor callbacks; the returned list owns only newly made corners.
/proc/create_all_lighting_corners(var/defer_activity = FALSE)
	var/list/fresh_corners = list()
	for (var/zlevel = 1 to max_lighting_z())
		fresh_corners += create_lighting_corners_zlevel(zlevel, defer_activity)
	if (!defer_activity)
		global.lighting_corners_initialised = TRUE
	return fresh_corners

// A later startup can add overlays to previously inactive, already shared
// corners. Once activated through an overlay master, further visits skip them.
// This uses no retained registry and does not reactivate fresh active corners.
/proc/activate_existing_lighting_corners()
	var/work = 0
	for (var/turf/T in world)
		if (T.lighting_overlay)
			for (var/datum/lighting_corner/C in T.corners)
				if (C && !C.active)
					C.update_active(TRUE)
		if (environment_sweep_pause(++work))
			work = 0

/proc/create_lighting_corners_zlevel(var/zlevel, var/defer_activity = FALSE)
	var/list/fresh_corners = list()
	var/work = 0
	for (var/turf/T in block(locate(1, 1, zlevel), locate(world.maxx, world.maxy, zlevel)))

		if (environment_sweep_pause(++work))
			work = 0
		if (!T.supports_lighting_overlays())
			continue

		if (istype(T, /turf/wall/rockwall) || istype(T, /turf/wall/indestructable))
			continue

		for (var/i = 1 to 4)
			if (T.corners[i]) // Already have a corner on this direction.
				continue

			var/datum/lighting_corner/C = new(T, LIGHTING_CORNER_DIAGONAL[i], defer_activity)
			T.corners[i] = C
			fresh_corners += C
	return fresh_corners

/hook/startup/proc/setup_lighting()
	create_lighting()
	return TRUE

var/created_lighting_corners_and_overlays = FALSE
/proc/create_lighting(_time_of_day)

	if (_time_of_day)
		time_of_day = _time_of_day
	else
		time_of_day = pick_TOD()

	created_lighting_corners_and_overlays = FALSE
	lighting_corners_initialised = FALSE
	lighting_startup_in_progress = TRUE
	try
		var/list/fresh_corners = create_all_lighting_corners(TRUE)
		create_all_lighting_overlays()
		create_startup_compatibility_overlays()
		// Yielding corner creation must not run activity callbacks before overlays.
		// Release consumed temporary references without retaining a startup registry.
		var/work = 0
		for (var/i = 1, i <= fresh_corners.len, i++)
			var/datum/lighting_corner/C = fresh_corners[i]
			fresh_corners[i] = null
			C.update_active(TRUE)
			if (environment_sweep_pause(++work))
				work = 0
		activate_existing_lighting_corners()
		lighting_corners_initialised = TRUE
		created_lighting_corners_and_overlays = TRUE
	catch (var/exception/E)
		lighting_startup_in_progress = FALSE
		lighting_corners_initialised = FALSE
		created_lighting_corners_and_overlays = FALSE
		throw E
	lighting_startup_in_progress = FALSE

// A restored round skips ticker.setup() and its roundstart hook, which is what
// normally applies daylight. Overlays built during pregame stay hidden from
// players (invisibility 100) and carry the startup time of day until daylight is
// applied, so world restoration applies the restored time of day for every
// restored round, including legacy saves without durable metadata. Imports run
// after startup has built the overlays.
/proc/apply_restored_lighting()
	var/process/time_of_day_change/P = processes.time_of_day_change
	if (!P || !created_lighting_corners_and_overlays)
		return FALSE
	// An in-flight worker pass applies its own target and settles time_of_day.
	if (P.updating_lighting)
		return TRUE
	P.lighting_revision++
	return P.apply_daylight(time_of_day, P.lighting_revision)

/proc/update_lighting(_time_of_day, var/client/admincaller = null, var/announce = TRUE)

	while (!created_lighting_corners_and_overlays)
		sleep(1)

	processes.time_of_day_change.changeto = _time_of_day
	processes.time_of_day_change.admincaller = admincaller
	processes.time_of_day_change.announce = announce
	processes.time_of_day_change.fire(TRUE)

// Run map effects for the completed request, after a queued target has settled.
/proc/apply_time_of_day_effects(target)
	if (target == "Night" && map && map.ID == MAP_NOMADS_WASTELAND_2)
		var/obj/map_metadata/nomads/wasteland/two/map2 = map
		map2.zombies(TRUE)
	if (target == "Morning" && map && map.ID == MAP_NOMADS_WASTELAND_2)
		var/obj/map_metadata/nomads/wasteland/two/map2 = map
		map2.zombies(FALSE)
