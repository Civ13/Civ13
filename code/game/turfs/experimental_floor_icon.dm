var/list/flooring_cache = list()

/turf/floor/update_icon(var/update_neighbors)

/*	if (lava)
		return*/

	if (flooring)
		// Set initial icon and strings.
		name = flooring.name
		desc = flooring.desc
		icon = flooring.icon
		if (!isnull(set_update_icon) && istext(set_update_icon))
			icon_state = set_update_icon
		else if (flooring_override)
			icon_state = flooring_override
		else
			if (overrided_icon_state)
				icon_state = overrided_icon_state
				flooring_override = icon_state
			else
				icon_state = flooring.icon_base
				if (flooring.has_base_range)
					icon_state = "[icon_state][rand(0,flooring.has_base_range)]"
					flooring_override = icon_state


		// Apply edges, corners, and inner corners.
		//overlays.Cut()
		var/has_border = FALSE

		if (isnull(set_update_icon) && (flooring.flags & TURF_HAS_EDGES))// && !calcborders)
			for (var/step_dir in cardinal)
				var/turf/floor/T = get_step(src, step_dir)
				//i suck at using operators...
				if (!istype(src, /turf/floor/winter/grass) && !istype(src, /turf/floor/dirt) && !istype(T, /turf/wall) && !istype(T, /turf/floor/broken_floor) && (!istype(T) || !T.flooring || T.flooring.name != flooring.name) && !(istype(T, /turf/floor/dirt) && istype(T, /turf/floor/grass)) && !(istype(T, /turf/floor/grass) && istype(src, /turf/floor/beach)) && !istype(T, /turf/floor/plating) && !(istype(src, /turf/floor/beach/sand) && istype(T, /turf/floor/beach/water)))
					has_border |= step_dir
					T.overlays |= get_flooring_overlay("[flooring.icon_base]-edge-[step_dir]", "[flooring.icon_base]_edges", step_dir)

			// There has to be a concise numerical way to do this but I am too noob.
			if (watertile == FALSE)

				if ((has_border & NORTH) && (has_border & EAST))
					var/turf/floor/T = get_step(src, NORTHEAST)
					if  (!istype(src, /turf/floor/winter/grass) && !istype(src, /turf/floor/dirt) && !istype(T, /turf/wall) && !istype(T, /turf/floor/broken_floor) && !(istype(T, /turf/floor/dirt) && istype(T, /turf/floor/grass)) && !(istype(T, /turf/floor/grass) && istype(src, /turf/floor/beach)) && !istype(T, /turf/floor/plating) && !(istype(src, /turf/floor/beach/sand) && istype(T, /turf/floor/beach/water)))
						T.overlays |= get_flooring_overlay("[flooring.icon_base]-edge-[NORTHEAST]", "[flooring.icon_base]_edges", NORTHEAST)
				if ((has_border & NORTH) && (has_border & WEST))
					var/turf/floor/T = get_step(src, NORTHWEST)
					if  (!istype(src, /turf/floor/winter/grass) && !istype(src, /turf/floor/dirt) && !istype(T, /turf/wall) && !istype(T, /turf/floor/broken_floor) && !(istype(T, /turf/floor/dirt) && istype(T, /turf/floor/grass)) && !(istype(T, /turf/floor/grass) && istype(src, /turf/floor/beach)) && !istype(T, /turf/floor/plating) && !(istype(src, /turf/floor/beach/sand) && istype(T, /turf/floor/beach/water)))
						T.overlays |= get_flooring_overlay("[flooring.icon_base]-edge-[NORTHWEST]", "[flooring.icon_base]_edges", NORTHWEST)
				if ((has_border & SOUTH) && (has_border & EAST))
					var/turf/floor/T = get_step(src, SOUTHEAST)
					if  (!istype(src, /turf/floor/winter/grass) && !istype(src, /turf/floor/dirt) && !istype(T, /turf/wall) && !istype(T, /turf/floor/broken_floor) && !(istype(T, /turf/floor/dirt) && istype(T, /turf/floor/grass)) && !(istype(T, /turf/floor/grass) && istype(src, /turf/floor/beach)) && !istype(T, /turf/floor/plating) && !(istype(src, /turf/floor/beach/sand) && istype(T, /turf/floor/beach/water)))
						T.overlays |= get_flooring_overlay("[flooring.icon_base]-edge-[SOUTHEAST]", "[flooring.icon_base]_edges", SOUTHEAST)
				if ((has_border & SOUTH) && (has_border & WEST))
					var/turf/floor/T = get_step(src, SOUTHWEST)
					if  (!istype(src, /turf/floor/winter/grass) && !istype(src, /turf/floor/dirt) && !istype(T, /turf/wall) && !istype(T, /turf/floor/broken_floor) && !(istype(T, /turf/floor/dirt) && istype(T, /turf/floor/grass)) && !(istype(T, /turf/floor/grass) && istype(src, /turf/floor/beach)) && !istype(T, /turf/floor/plating) && !(istype(src, /turf/floor/beach/sand) && istype(T, /turf/floor/beach/water)))
						T.overlays |= get_flooring_overlay("[flooring.icon_base]-edge-[SOUTHWEST]", "[flooring.icon_base]_edges", SOUTHWEST)

				if (flooring.flags & TURF_HAS_CORNERS && !calcborders)
					// As above re: concise numerical way to do this.
					if (!(has_border & NORTH))
						if (!(has_border & EAST))
							var/turf/floor/T = get_step(src, NORTHEAST)
							if (!istype(T, /turf/wall) && !istype(T, /turf/floor/broken_floor) && !T.watertile)
								T.overlays |= get_flooring_overlay("[flooring.icon_base]-corner-[NORTHEAST]", "[flooring.icon_base]_corners", NORTHEAST)
						if (!(has_border & WEST))
							var/turf/floor/T = get_step(src, NORTHWEST)
							if (!istype(T, /turf/wall) && !istype(T, /turf/floor/broken_floor) && !T.watertile)
								T.overlays |= get_flooring_overlay("[flooring.icon_base]-corner-[NORTHWEST]", "[flooring.icon_base]_corners", NORTHWEST)
					if (!(has_border & SOUTH))
						if (!(has_border & EAST))
							var/turf/floor/T = get_step(src, SOUTHEAST)
							if (!istype(T, /turf/wall) && !istype(T, /turf/floor/broken_floor) && !T.watertile)
								T.overlays |= get_flooring_overlay("[flooring.icon_base]-corner-[SOUTHEAST]", "[flooring.icon_base]_corners", SOUTHEAST)
						if (!(has_border & WEST))
							var/turf/floor/T = get_step(src, SOUTHWEST)
							if (!istype(T, /turf/wall) && !istype(T, /turf/floor/broken_floor) && !T.watertile)
								T.overlays |= get_flooring_overlay("[flooring.icon_base]-corner-[SOUTHWEST]", "[flooring.icon_base]_corners", SOUTHWEST)
		calcborders = TRUE
	if (decals && decals.len)
		overlays |= decals

	if (flooring)
		if (!isnull(broken) && (flooring.flags & TURF_CAN_BREAK))
			overlays |= get_flooring_overlay("[flooring.icon_base]-broken-[broken]", "broken[broken]")
		if (!isnull(burnt) && (flooring.flags & TURF_CAN_BURN))
			overlays |= get_flooring_overlay("[flooring.icon_base]-burned-[burnt]", "burned[burnt]")

	if (update_neighbors)
		for (var/turf/floor/F in range(src, TRUE))
			if (F == src)
				continue
			F.update_icon()
/turf/floor/proc/get_flooring_overlay(var/cache_key, var/icon_base, var/icon_dir = FALSE)
	if (!flooring_cache[cache_key])
		var/image/I = image(icon = flooring.icon, icon_state = icon_base, dir = icon_dir)
		I.layer = layer+0.1
		flooring_cache[cache_key] = I
	return flooring_cache[cache_key]