/area/proc/update_snowfall_valid_turfs()
	if (artillery_integrity <= 20 || location == AREA_OUTSIDE)
		for (var/turf/floor/F in contents)
			if (istype(F))
				snowfall_valid_turfs |= F