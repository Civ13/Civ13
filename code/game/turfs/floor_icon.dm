var/list/flooring_cache = list()

/turf/floor/New()
	..()
	if (!flooring)
		return
	// Set initial icon and strings.
	name = flooring.name
	desc = flooring.desc
	icon = flooring.icon
	if (!isnull(set_update_icon) && istext(set_update_icon))
		icon_state = set_update_icon
	else if (flooring_override)
		icon_state = flooring_override
	else if (overrided_icon_state)
		icon_state = overrided_icon_state
		flooring_override = icon_state
	else
		icon_state = flooring.icon_base
		if (flooring.has_base_range)
			icon_state = "[icon_state][rand(0, flooring.has_base_range)]"
			flooring_override = icon_state

/turf/floor/update_icon(var/update_neighbors)
	if (flooring)
		// Apply edges, corners, and inner corners.
		overlays.Cut()
		var/has_border = 0
		var/base = flooring.icon_base
		if (isnull(set_update_icon) && (flooring.flags & TURF_HAS_EDGES))
			for (var/step_dir in cardinal)
				var/turf/T = get_step(src, step_dir)
				var/is_border = FALSE
				if (flooring.flags & SMOOTH_ONLY_WITH_ITSELF)
					var/turf/floor/F = T
					if (!istype(F) || !F.flooring || F.flooring.name != flooring.name)
						is_border = TRUE
				else
					if (istype(T, /turf/floor/broken_floor))
						is_border = TRUE
				
				if (is_border)
					has_border |= step_dir
					overlays |= get_flooring_overlay("[base]-edge-[step_dir]", "[base]_edges", step_dir)

			for (var/diag_dir in list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
				if ((has_border & diag_dir) == diag_dir)
					overlays |= get_flooring_overlay("[base]-edge-[diag_dir]", "[base]_edges", diag_dir)

			if (flooring.flags & TURF_HAS_CORNERS)
				for (var/diag_dir in list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
					if (!(has_border & diag_dir))
						var/turf/T = get_step(src, diag_dir)
						var/is_border = FALSE
						if (flooring.flags & SMOOTH_ONLY_WITH_ITSELF)
							var/turf/floor/F = T
							if (!istype(F) || !F.flooring || F.flooring.name != flooring.name)
								is_border = TRUE
						else
							if (istype(T, /turf/floor/broken_floor))
								is_border = TRUE
						if (is_border)
							overlays |= get_flooring_overlay("[base]-corner-[diag_dir]", "[base]_corners", diag_dir)

	if (decals && decals.len)
		overlays |= decals

	if (flooring)
		if (!isnull(broken) && (flooring.flags & TURF_CAN_BREAK))
			overlays |= get_flooring_overlay("[flooring.icon_base]-broken-[broken]", "broken[broken]")
		if (!isnull(burnt) && (flooring.flags & TURF_CAN_BURN))
			overlays |= get_flooring_overlay("[flooring.icon_base]-burned-[burnt]", "burned[burnt]")

	if (update_neighbors)
		for (var/turf/floor/F in range(1, src))
			if (F != src)
				F.update_icon()

	var/has_irradiated_prefix = findtext(name, "irradiated")
	if (radiation >= 15)
		if (!has_irradiated_prefix)
			if (istype(src, /turf/floor/grass))
				var/turf/floor/grass/G = src
				if (G.deadicon_state != "none" && G.icon_state != G.deadicon_state)
					name = "irradiated [name]"
					G.icon = G.deadicon
					G.icon_state = G.deadicon_state
			else if (istype(src, /turf/floor/winter/grass))
				var/turf/floor/winter/grass/WG = src
				if (WG.deadicon_state != "none" && WG.icon_state != WG.deadicon_state)
					name = "irradiated [name]"
					WG.icon = WG.deadicon
					WG.icon_state = WG.deadicon_state
			else if (istype(src, /turf/floor/beach/water) && radiation >= 20)
				name = "irradiated [name]"
		if (istype(src, /turf/floor/beach/water) && radiation >= 20)
			overlays += image(icon, "seashallow_swamp_overlay")
	else if (has_irradiated_prefix)
		name = replacetext(name, "irradiated ", "")

/turf/floor/proc/get_flooring_overlay(var/cache_key, var/icon_base, var/icon_dir = FALSE)
	if (!flooring_cache[cache_key])
		var/image/I = image(icon = flooring.icon, icon_state = icon_base, dir = icon_dir)
		I.layer = layer
		flooring_cache[cache_key] = I
	return flooring_cache[cache_key]