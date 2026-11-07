// Lazy lighting for added open-air building levels. Kept apart from
// building_levels.dm so the isolated persistence fixtures that compile that
// file alone need no lighting globals.

// A floor or a replacement wakes the open-air cells a player standing there
// can see: registry entry, window coefficient, shared corners and a lighting
// overlay, as a startup cell has. The cost of an added plane follows what is
// built on it, not its size. Woken cells keep the sparse baseline until a
// saved field differs; lighting state is not saved.
#define BUILDING_WAKE_RANGE 7

/proc/building_level_lazy(z)
	return z > building_base_maxz() && z != dug_underground_z()

/proc/building_wake_cells(turf/center)
	if (!center || !created_lighting_corners_and_overlays || building_allocating_z || !building_level_lazy(center.z))
		return
	for (var/turf/sky/building/T in range(BUILDING_WAKE_RANGE, center))
		if (T.z == center.z)
			T.building_wake()

/turf/sky/building/proc/building_wake()
	if (turf_registry_members[src])
		return
	turf_registry_members[src] = TRUE
	turfs += src
	calculate_window_coeff()
	if (map && map.zlevels_without_lighting.Find(z))
		return
	for (var/i = 1 to 4)
		if (!get_corner(i))
			set_corner(i, new /datum/lighting_corner(src, LIGHTING_CORNER_DIAGONAL[i]))
	lighting_build_overlay()

/turf/sky/building/ChangeTurf(var/path, var/tell_universe = 1, var/force_lighting_update = FALSE, datum/durable_nomads_event/nomads_event = null)
	building_wake_cells(src)
	return ..()
