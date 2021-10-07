/var/list/lighting_update_overlays  = list()	// List of lighting overlays queued for update.

/atom/movable/lighting_overlay
	name			 = ""

	icon			 = 'icons/effects/icon.png'
	color			= LIGHTING_BASE_MATRIX

	mouse_opacity	= FALSE
	plane			= LIGHTING_PLANE
	layer			= LIGHTING_LAYER
	invisibility	 = INVISIBILITY_LIGHTING

	simulated = FALSE
	anchored = TRUE
	flags = NOREACT

	blend_mode	   = BLEND_MULTIPLY

	var/needs_update = FALSE

	var/TOD = "Midday"

/atom/movable/lighting_overlay/pre_bullet_act(var/obj/item/projectile/P)
	return FALSE

/atom/movable/lighting_overlay/New(var/atom/loc, var/no_update = FALSE)
	. = ..()
	verbs.Cut()

	layer			  = 13 // The lighting overlay should appear above everything including weather effects
	var/turf/T		 = loc // If this runtimes atleast we'll know what's creating overlays in things that aren't turfs.
	if (T)
		T.lighting_overlay = src
		T.luminosity	   = FALSE

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

/atom/movable/lighting_overlay/proc/update_overlay()
	var/turf/T = loc
	if (!T || !istype(T)) // Erm...
		if (loc)
			warning("A lighting overlay realised its loc was NOT a turf (actual loc: [loc], [loc.type]) in update_overlay() and got pooled!")

		else
			warning("A lighting overlay realised it was in nullspace in update_overlay() and got pooled!")

		qdel(src)
		return

	T.calculate_window_coeff()

	blend_mode = BLEND_MULTIPLY

	var/list/L = copylist(color)
	if (!islist(L))
		L = list()

	var/anylums = FALSE

	var/TOD_lum = time_of_day2luminosity[time_of_day] * T.window_coeff
	for (var/datum/lighting_corner/C in T.corners)
		var/i = 0

		var/adjusted_r = C.lum_r + TOD_lum
		var/adjusted_g = C.lum_g + TOD_lum
		var/adjusted_b = C.lum_b + TOD_lum

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

		var/mx = max(adjusted_r, adjusted_g, adjusted_b) // Scale it so 1 is the strongest lum, if it is above 1.
		anylums += mx
		. = 1.0 // factor
		if (mx > 1)
			. = 1.0 / mx

		L[i + 0]   = adjusted_r * .
		L[i + 1]   = adjusted_g * .
		L[i + 2]   = adjusted_b * .

	color  = L
	luminosity = (anylums > 0)