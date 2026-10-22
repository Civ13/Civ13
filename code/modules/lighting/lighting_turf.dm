/area
	// Pre-startup author switch, not a certificate of source/appearance clearance.
	// Leave false unless a frozen declared-clearance review covers this region.
	var/tmp/lighting_reserved_clearance_enabled = FALSE

/turf
	// Map-authored, pre-startup policy only. Never infer this from empty space or z.
	// Activation is one-way; imported cells deliberately fail open to ordinary lighting.
	var/tmp/lighting_reserved = FALSE
	var/dynamic_lighting = TRUE
	luminosity		   = TRUE

	var/window_coeff = 0.25
	var/window_coeff_dirty = TRUE

	var/list/affecting_lights	   // List of light sources affecting this turf.
	var/tmp/atom/movable/lighting_overlay/lighting_overlay // Our lighting overlay.
	var/tmp/list/datum/lighting_corner/corners[4]
	var/tmp/has_opaque_atom = FALSE // Not to be confused with opacity, this will be TRUE if there's any opaque atom on the tile.

	// misc
	var/next_calculate_window_coeff = -1

/turf/New()
	. = ..()

	if (opacity)
		has_opaque_atom = TRUE
	// Initial map turfs are covered by bulk startup, without one sleeper each.
	// Replacements made during startup still retain their runtime request.
	if (created_lighting_corners_and_overlays || lighting_startup_in_progress)
		spawn(5)
			var/area/A = get_area(src)
			if (A && A.dynamic_lighting)
				lighting_build_overlay()
			sync_fullbright_coverage()

/turf/proc/get_window_coeff()
	if (window_coeff_dirty)
		calculate_window_coeff()
	return window_coeff

// Causes any affecting light sources to be queued for a visibility update, for example a door got opened.
/turf/proc/reconsider_lights()
	for (var/A in affecting_lights)
		if (!A)
			continue

		var/datum/light_source/L = A
		L.vis_update()

/turf/proc/lighting_clear_overlay()
	if (lighting_overlay)
		qdel(lighting_overlay)
		#if LIGHTING_COMPOSITION_V2
		lighting_overlay = null
		#endif
	sync_fullbright_coverage()

	for (var/A in corners)
		if (!A)
			continue

		var/datum/lighting_corner/C = A
		C.update_active()

// Builds a lighting overlay for us, but only if our area is dynamic.
/turf/proc/lighting_build_overlay()
	// Only actual runtime requests can wait here; initial map New schedules none.
	var/startup_request = FALSE
	while (lighting_startup_in_progress)
		startup_request = TRUE
		sleep(world.tick_lag)
	// An interrupted startup releases its waiters without publishing readiness.
	if (startup_request && !created_lighting_corners_and_overlays)
		return
	if (omit_reserved_lighting_overlay())
		return
	if (!lighting_overlay)
		var/area/A = loc
		if (A && A.dynamic_lighting)
			PoolOrNew(/atom/movable/lighting_overlay, src)

			for (var/LC in corners)
				if (!LC)
					continue

				var/datum/lighting_corner/C = LC
				if (!C.active) // We would activate the corner, calculate the lighting for it.
					for (var/L in C.affecting)
						var/datum/light_source/S = L
						S.recalc_corner(C)

					C.active = TRUE

// DAYLIGHT RELATED MEMBER PROCS

// make this turf have a darkness level based on the time of day
/turf/proc/adjust_lighting_overlay_to_daylight()
	if (istype(src, /turf/floor/beach/water/ice))
		fix_corners_and_lighting_overlay()
	if (lighting_overlay)
		lighting_overlay.update_overlay()

// HACKCODE

/turf/proc/fix_broken_daylights()
	var/area/A = get_area(src)
	if (!A.dynamic_lighting)
		adjust_lighting_overlay_to_daylight()
		reconsider_lights()

/turf/proc/fix_corners_and_lighting_overlay() // workaround for broken ice corners
	for (var/i = 1 to 4)
		if (corners[i]) // Already have a corner on this direction.
			continue

		corners[i] = new/datum/lighting_corner(src, LIGHTING_CORNER_DIAGONAL[i])
	for (var/atom/movable/lighting_overlay/LO in contents)
		lighting_overlay = LO
		break

// Used to get a scaled lumcount.
/turf/proc/get_lumcount(var/minlum = 0, var/maxlum = 1)
	if (!lighting_overlay)
		// Only an intentional omission can use the retained production graph.
		// Ordinary mask-free cells and incomplete startup keep their fallback.
		if (lighting_startup_in_progress || !created_lighting_corners_and_overlays || !omit_reserved_lighting_overlay())
			return 0.5
		if (!corners || corners.len != 4)
			return 0.5
		for (var/i = 1 to 4)
			if (!corners[i])
				return 0.5
		// An omitted overlay cannot refresh its turf's daylight coefficient.
		get_window_coeff()

	var/TOD_lum = time_of_day2luminosity[time_of_day] * window_coeff
	var/totallums = 0
	for (var/LL in corners)
		var/datum/lighting_corner/L = LL
		totallums += L.lum_r + L.lum_g + L.lum_b + TOD_lum*3

	totallums /= 12 // 4 corners, each with 3 channels, get the average.

	totallums = (totallums - minlum) / (maxlum - minlum)

	return CLAMP01(totallums)

// Can't think of a good name, this proc will recalculate the has_opaque_atom variable.
/turf/proc/recalc_atom_opacity()
	has_opaque_atom = FALSE
	for (var/atom/A in contents + src) // Loop through every movable atom on our tile PLUS ourselves (we matter too...)
		if (A.opacity)
			has_opaque_atom = TRUE

// If an opaque movable atom moves around we need to potentially update visibility.
/turf/Entered(var/atom/movable/Obj, var/atom/OldLoc)
	. = ..()

	if (Obj && Obj.opacity)
		has_opaque_atom = TRUE // Make sure to do this before reconsider_lights(), incase we're on instant updates. Guaranteed to be on in this case.
		reconsider_lights()

/turf/Exited(var/atom/movable/Obj, var/atom/newloc)
	. = ..()

	if (Obj && Obj.opacity)
		recalc_atom_opacity() // Make sure to do this before reconsider_lights(), incase we're on instant updates.
		reconsider_lights()

/turf/change_area(var/area/old_area, var/area/new_area)
	if (new_area && old_area && new_area.location != old_area.location)
		window_coeff_dirty = TRUE
	if (new_area.dynamic_lighting != old_area.dynamic_lighting)
		if (new_area.dynamic_lighting)
			lighting_build_overlay()

		else
			lighting_clear_overlay()

	sync_fullbright_coverage()

/turf/proc/get_corners(var/dir)
	if (has_opaque_atom)
		return null // Since this proc gets used in a for loop, null won't be looped though.

	return corners

/turf/proc/calculate_window_coeff()
	var/area/src_area = loc
	if (src_area && istype(src_area, /area/caribbean/dark))
		window_coeff = 0.5
	else if (src_area && src_area.location == AREA_OUTSIDE)
		window_coeff = 1.0
	else
		window_coeff = 0.5

	for (var/datum/lighting_corner/C in corners)
		C.window_coeff = window_coeff

	window_coeff_dirty = FALSE


// don't put this proc anywhere other than where it already is, because it checks for the lack of lighting overlays - Kachnov
/turf/proc/supports_lighting_overlays()
	. = TRUE
	if (locate(/atom/movable/lighting_overlay) in src)
		. = FALSE
	if (map && map.zlevels_without_lighting.Find(z))
		. = FALSE

	var/area/src_area = get_area(src)
	if (!src_area.dynamic_lighting)
		. = FALSE

	return .

// Keep the ordinary corner graph and a visible one-tile halo. No shared corner
// is removed. Map authors may opt in only unreachable, not-yet-built interiors.
/turf/proc/omit_reserved_lighting_overlay()
	if (!lighting_reserved)
		return FALSE
	if (x == 1 || y == 1 || x == world.maxx || y == world.maxy)
		return FALSE
	var/area/A = get_area(src)
	if (!A || !A.dynamic_lighting || A.lighting_reserved_clearance_enabled != TRUE)
		return FALSE
	for (var/turf/T in range(1, src))
		if (!T.lighting_reserved)
			return FALSE
	return TRUE

// Clearing a reservation exposes the neighboring halo as well. Existing corner
// luminosities and source memberships are current even while overlays are absent.
/turf/proc/activate_reserved_lighting()
	if (!lighting_reserved)
		return
	lighting_reserved = FALSE
	if (lighting_startup_in_progress)
		// Never make a bulk-startup owner wait on its own readiness barrier.
		spawn()
			while (lighting_startup_in_progress)
				sleep(world.tick_lag)
			if (created_lighting_corners_and_overlays)
				refresh_reserved_lighting_halo()
		return
	if (!created_lighting_corners_and_overlays)
		return
	refresh_reserved_lighting_halo()

/turf/proc/refresh_reserved_lighting_halo()
	for (var/turf/T in range(1, src))
		if (!T.omit_reserved_lighting_overlay())
			T.lighting_build_overlay()
			if (T.lighting_overlay)
				T.lighting_overlay.TOD = time_of_day
				T.lighting_overlay.update_overlay()
				if (processes.time_of_day_change && processes.time_of_day_change.setup_lighting)
					T.lighting_overlay.invisibility = 0
