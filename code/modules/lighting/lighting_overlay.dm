/var/list/lighting_update_overlays  = list()    // List of lighting overlays queued for update.

/atom/movable/lighting_overlay
	name             = ""

	icon             = 'icons/effects/icon.png'
	color            = LIGHTING_BASE_MATRIX

	mouse_opacity    = FALSE
	plane            = LIGHTING_PLANE
	layer            = LIGHTING_LAYER
	invisibility     = INVISIBILITY_LIGHTING

	simulated = FALSE
	anchored = TRUE
	flags = NOREACT

	blend_mode       = BLEND_MULTIPLY

	var/needs_update = FALSE

	var/TOD = "Midday"

/atom/movable/lighting_overlay/pre_bullet_act(var/obj/item/projectile/P)
	return FALSE

/atom/movable/lighting_overlay/New(var/atom/loc, var/no_update = FALSE)
	. = ..()
	verbs.Cut()

	var/turf/T         = loc // If this runtimes atleast we'll know what's creating overlays in things that aren't turfs.
	T.lighting_overlay = src
	T.luminosity       = FALSE

	if (no_update)
		return

	update_overlay()

	// so observers can actually see things
	if (!ticker || ticker.current_state == GAME_STATE_PREGAME)
		invisibility = 100

	lighting_overlay_list += src

/atom/movable/lighting_overlay/Destroy()
	var/turf/T   = loc
	if (istype(T))
		T.lighting_overlay = null

		T.luminosity = TRUE

	lighting_update_overlays -= src

	..()

/atom/movable/lighting_overlay/Destroy()
	lighting_overlay_list -= src
	..()

/atom/movable/lighting_overlay/proc/update_overlay(var/force_window_coeff_updates = FALSE)
	var/turf/T = loc
	if (!T || !istype(T)) // Erm...
		if (loc)
			warning("A lighting overlay realised its loc was NOT a turf (actual loc: [loc], [loc.type]) in update_overlay() and got pooled!")

		else
			warning("A lighting overlay realised it was in nullspace in update_overlay() and got pooled!")

		qdel(src)
		return

	if (force_window_coeff_updates)
		T.calculate_window_coeff()
	//	T.next_calculate_window_coeff = world.time + 300

	blend_mode = BLEND_MULTIPLY

	var/list/L = copylist(color)
	if (!islist(L))
		L = list()

	var/anylums = FALSE

	for (var/datum/lighting_corner/C in T.corners)
		var/i = 0

		// Huge switch to determine i based on D.
		switch(turn(C.masters[T], 180))
			if (NORTHEAST)
				i = AR

			if (SOUTHEAST)
				i = GR

			if (SOUTHWEST)
				i = RR

			if (NORTHWEST)
				i = BR

		var/mx = max(C.getLumR(T), C.getLumG(T), C.getLumB(T)) // Scale it so 1 is the strongest lum, if it is above 1.
		anylums += mx
		. = 1.0 // factor
		if (mx > 1)
			. = 1.0 / mx

		L[i + 0]   = C.getLumR(T) * .
		L[i + 1]   = C.getLumG(T) * .
		L[i + 2]   = C.getLumB(T) * .

	color  = L
	luminosity = (anylums > 0)