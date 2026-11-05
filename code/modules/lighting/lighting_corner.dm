// Because we can control each corner of every lighting overlay.
// And corners get shared between multiple turfs (unless you're on the corners of the map, then TRUE corner doesn't).
// For the record: these should never ever ever be deleted, even if the turf doesn't have dynamic lighting.

// This list is what the code that assigns corners listens to, the order in this list is the order in which corners are added to the /turf/corners list.
/var/list/LIGHTING_CORNER_DIAGONAL = list(NORTHEAST, SOUTHEAST, SOUTHWEST, NORTHWEST)

// A corner sits between up to four turfs (its masters). Their identity and the
// direction from the corner to each follow from the corner's position, so no
// per-corner list is kept: Gaia has 292k corners and a four-entry turf-keyed
// list cost about 400 bytes each.
/datum/lighting_corner
	var/list/datum/light_source/affecting // Light sources affecting us.
	var/active							= FALSE  // TRUE if one of our masters has dynamic lighting.

	var/x	 = 0
	var/y	 = 0
	var/z	 = 0

	// luminosity values based on lights
	var/lum_r = 0.0
	var/lum_g = 0.0
	var/lum_b = 0.0

	// luminosity values based on the time of day
	var/window_coeff = 0.25

// Direction from this corner to the master turf T (one of the four turfs
// around the corner). This is what the masters list used to store per turf.
/datum/lighting_corner/proc/master_direction(var/turf/T)
	return ((T.x > x) ? EAST : WEST) | ((T.y > y) ? NORTH : SOUTH)

// The master turf in the given LIGHTING_CORNER_DIAGONAL direction (NE, SE,
// SW, NW), or null past the map border.
/datum/lighting_corner/proc/master_turf(var/i)
	switch(i)
		if (1)
			return locate(x + 0.5, y + 0.5, z)
		if (2)
			return locate(x + 0.5, y - 0.5, z)
		if (3)
			return locate(x - 0.5, y - 0.5, z)
		if (4)
			return locate(x - 0.5, y + 0.5, z)
	return null

// The master a light source attributes this corner to. Startup creates each
// corner from the lowest turf index that touches it, which is the south-west
// master; use that turf whenever it exists so the choice is deterministic.
/datum/lighting_corner/proc/first_master()
	for (var/i in list(3, 2, 4, 1))
		var/turf/T = master_turf(i)
		if (T)
			return T
	return null

/datum/lighting_corner/proc/master_count()
	. = 0
	for (var/i = 1, i <= 4, i++)
		if (master_turf(i))
			.++

/datum/lighting_corner/New(var/turf/new_turf, var/diagonal, var/defer_activity = FALSE)
	. = ..()

	var/vertical   = diagonal & ~(diagonal - 1) // The horizontal directions (4 and 8) are bigger than the vertical ones (1 and 2), so we can reliably say the lsb is the horizontal direction.
	var/horizontal = diagonal & ~vertical	   // Now that we know the horizontal one we can get the vertical one.

	x = new_turf.x + (horizontal == EAST  ? 0.5 : -0.5)
	y = new_turf.y + (vertical   == NORTH ? 0.5 : -0.5)
	z = new_turf.z

	// My initial plan was to make this loop through a list of all the dirs (horizontal, vertical, diagonal).
	// Issue being that the only way I could think of doing it was very messy, slow and honestly overengineered.
	// So we'll have this hardcode instead.
	var/turf/T
	var/i

	// Diagonal one is easy.
	T = get_step(new_turf, diagonal)
	if (T) // In case we're on the map's border.
		i			= LIGHTING_CORNER_DIAGONAL.Find(turn(diagonal, 180))
		T.corners[i] = src

	// Now the horizontal one.
	T = get_step(new_turf, horizontal)
	if (T) // Ditto.
		i			= LIGHTING_CORNER_DIAGONAL.Find(turn(master_direction(T), 180))
		T.corners[i] = src

	// And finally the vertical one.
	T = get_step(new_turf, vertical)
	if (T)
		i			= LIGHTING_CORNER_DIAGONAL.Find(turn(master_direction(T), 180))
		T.corners[i] = src

	// Ordinary runtime construction keeps its deferred callback. Startup owns
	// activation explicitly after the overlay barrier, because discovery yields.
	if (!defer_activity)
		var/startup_activity = lighting_startup_in_progress
		spawn()
			while (lighting_startup_in_progress)
				startup_activity = TRUE
				sleep(world.tick_lag)
			if (!startup_activity || created_lighting_corners_and_overlays)
				update_active()

/datum/lighting_corner/proc/update_active(var/startup_owner = FALSE)
	// Direct clear/area-change requests also respect the startup barrier.
	var/startup_request = FALSE
	while (lighting_startup_in_progress && !startup_owner)
		startup_request = TRUE
		sleep(world.tick_lag)
	if (startup_request && !created_lighting_corners_and_overlays)
		return
	active = FALSE
	for (var/i = 1, i <= 4, i++)
		var/turf/T = master_turf(i)
		if (!T)
			continue
		if (T.lighting_overlay || T.omit_reserved_lighting_overlay())
			active = TRUE

// God that was a mess, now to do the rest of the corner code! Hooray!
/datum/lighting_corner/proc/update_lumcount(var/delta_r, var/delta_g, var/delta_b)
//(time_of_day2luminosity[time_of_day] * window_coeff
	lum_r += delta_r
	lum_g += delta_g
	lum_b += delta_b

	for (var/i = 1, i <= 4, i++)
		var/turf/T = master_turf(i)
		if (!T)
			continue
		if (T.lighting_overlay)
			#ifdef LIGHTING_INSTANT_UPDATES
			T.lighting_overlay.update_overlay()
			#else
			if (!T.lighting_overlay.needs_update)
				#if CIV13_ROOT_TREE_PRESENTATION
				root_tree_light_changed(T)
				#endif
				T.lighting_overlay.needs_update = TRUE
				lighting_update_overlays += T.lighting_overlay
			#endif
