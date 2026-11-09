/var/list/lighting_update_overlays  = list()	// List of lighting overlays queued for update.

// TRUE when daylight is added on each client's light mask plane master
// (plane_master.dm) rather than baked into every overlay's matrix here. The
// server then changes the time of day with one appearance per client instead
// of a 350k-overlay sweep. Needs the V2 mask plane; off by default (config
// DAYNIGHT_CLIENT_TINT) until the look is signed off.
/proc/daylight_on_client()
	#ifdef OPENDREAM
	return FALSE
	#else
	return LIGHTING_COMPOSITION_V2 && config && config.daynight_client_tint
	#endif

// The daylight term for a cell: its luminosity times its window coefficient.
/proc/daylight_lum(window_coeff = 1)
	return time_of_day2luminosity[time_of_day] * window_coeff

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
	// The committed matrix lives in the shared appearance (color); a private
	// last_color copy per overlay cost about 500 bytes times ~350k Gaia turfs.
	var/tmp/color_committed = FALSE
	var/last_luminosity
	// Slot in lighting_overlay_list, so leaving it is O(1). That list holds
	// one overlay per lit turf (about a million on Gaia), and `list -= src`
	// scanned it: about 1 ms per destroyed overlay, seconds per season sweep.
	var/tmp/registry_index = 0

/atom/movable/lighting_overlay/pre_bullet_act(var/obj/item/projectile/P)
	return FALSE

/atom/movable/lighting_overlay/New(var/atom/loc, var/no_update = FALSE)
	var/turf/reserved_turf = loc
	if (isturf(reserved_turf) && reserved_turf.omit_reserved_lighting_overlay())
		// Deferred cleanup must never clear an overlay activated after refusal.
		src.loc = null
		qdel(src)
		return
	. = ..()
	#ifdef OPENDREAM
	blend_mode = BLEND_ADD
	invisibility = 0
	#endif
	#ifndef OPENDREAM
	#if LIGHTING_COMPOSITION_V2
	plane = LIGHTING_MASK_PLANE
	blend_mode = BLEND_OVERLAY
	#endif
	#endif
	verbs.Cut()

	layer			  = 13 // The lighting overlay should appear above everything including weather effects
	var/turf/T		 = loc // If this runtimes at least we'll know what's creating overlays in things that aren't turfs.
	if (T)
		T.lighting_overlay = src
		T.luminosity	   = FALSE
		T.sync_fullbright_coverage()

	if (no_update)
		return

	update_overlay()

	// so observers can actually see things
	if (!ticker || ticker.current_state == GAME_STATE_PREGAME)
		invisibility = 100
	#ifdef OPENDREAM
	invisibility = 0
	#endif

	lighting_overlay_register()

/atom/movable/lighting_overlay/proc/lighting_overlay_register()
	if (registry_index && registry_index <= lighting_overlay_list.len && lighting_overlay_list[registry_index] == src)
		return
	lighting_overlay_list += src
	registry_index = lighting_overlay_list.len

// Swap-remove: the last overlay takes this slot. Order is not meaningful.
/atom/movable/lighting_overlay/proc/lighting_overlay_unregister()
	var/index = registry_index
	registry_index = 0
	var/count = lighting_overlay_list.len
	if (!index || index > count || lighting_overlay_list[index] != src)
		// Added without a slot (direct list edits): fall back to the scan.
		lighting_overlay_list -= src
		return
	if (index != count)
		var/atom/movable/lighting_overlay/last = lighting_overlay_list[count]
		lighting_overlay_list[index] = last
		if (istype(last))
			last.registry_index = index
	lighting_overlay_list.len = count - 1

/atom/movable/lighting_overlay/Destroy()
	var/turf/T   = loc
	if (istype(T) && T.lighting_overlay == src)
		T.lighting_overlay = null

		T.luminosity = TRUE

	lighting_update_overlays -= src

	..()

/atom/movable/lighting_overlay/Destroy()
	lighting_overlay_unregister()
	..()

/proc/copylist(var/list/L)
	if (!L || !islist(L))
		return list()
	return L.Copy()

/atom/movable/lighting_overlay/proc/update_overlay()
	var/turf/T = loc
	if (!T || !istype(T)) // Erm...
		if (loc)
			warning("A lighting overlay realised its loc was NOT a turf (actual loc: [loc], [loc.type]) in update_overlay() and got pooled!")

		else
			warning("A lighting overlay realised it was in nullspace in update_overlay() and got pooled!")

		qdel(src)
		return
	var/client_tint = daylight_on_client()
	// On the client the mask's alpha is the cell's window coefficient (the
	// matrix's constant alpha below), so the plane master's matrix adds
	// daylight times alpha: full outside, half indoors. BYOND folds the alpha
	// var into a colour matrix, so the coefficient is written into the matrix.
	var/TOD_lum = client_tint ? 0 : daylight_lum(T.get_window_coeff())
	#ifdef OPENDREAM
	blend_mode = BLEND_ADD
	#endif
	#ifndef OPENDREAM
	// Opt-in masks compose on a separate light-only plane.
	blend_mode = LIGHTING_COMPOSITION_V2 ? BLEND_OVERLAY : BLEND_MULTIPLY
	#endif
	var/list/L = color ? copylist(color) : list()
	#ifdef OPENDREAM
	if (!color)
		L = LIGHTING_BASE_MATRIX
	#endif

	var/anylums = FALSE

	for (var/ci = 1 to 4)
		var/datum/lighting_corner/C = T.get_corner(ci)
		if (!C)
			continue
		var/i = 0

		var/adjusted_r = C.lum_r + TOD_lum
		var/adjusted_g = C.lum_g + TOD_lum
		var/adjusted_b = C.lum_b + TOD_lum

		// Huge switch to determine i based on D.
		switch(turn(C.master_direction(T), 180))
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

	if (L.len >= 20)
		L[20] = client_tint ? T.get_window_coeff() : 1

	var/new_luminosity = (anylums > 0)

	// Check against last values for early return (the committed matrix in color)
	var/list/last_color = color_committed ? color : null
	if (last_color && islist(last_color) && last_luminosity == new_luminosity)
		var/identical = TRUE
		if (L.len != last_color.len)
			identical = FALSE
		else
			for (var/i = 1; i <= L.len; i++)
				if (L[i] != last_color[i])
					identical = FALSE
					break
		if (identical)
			return

	// An unchanged update must not withdraw/re-publish client tree images.
	// Pending-corner notifications retain the still-displayed committed mask.
	#if CIV13_ROOT_TREE_PRESENTATION
	root_tree_light_changed(loc)
	#endif
	// Update last values and apply changes
	last_luminosity = new_luminosity
	color = L.Copy()
	color_committed = TRUE
	luminosity = new_luminosity
