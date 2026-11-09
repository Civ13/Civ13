//Takes: Area type as text string or as typepath OR an instance of the area.
//Returns: A list of all turfs in areas of that type in the world.
/proc/get_area_turfs(var/areatype, var/list/predicates)
	if (!areatype) return null
	else if (istext(areatype)) areatype = text2path(areatype)
	else if (isarea(areatype))
		var/area/areatemp = areatype
		areatype = areatemp.type

	var/list/turfs = list()
	for (var/area/A in area_list)
		if (istype(A, areatype))
			for (var/turf/T in A.contents)
				if (!predicates || all_predicates_true(list(T), predicates))
					turfs += T
	return turfs

/proc/pick_area_turf(var/areatype, var/list/predicates)
	var/list/turfs = get_area_turfs(areatype, predicates)
	if (turfs && turfs.len)
		return pick(turfs)
