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

/proc/get_area_width(var/area/a) //takes an actual area or a type
	var/list/turfs = get_area_turfs(a)
	var/maxDistX = FALSE

	for (var/turf/t in turfs)
		for (var/turf/tt in turfs)
			if (istype(t) && istype(tt))
				maxDistX = max(maxDistX, abs(t.x - tt.x))

	return maxDistX + 1

/proc/get_area_height(var/area/a)
	var/list/turfs = get_area_turfs(a)
	var/maxDistY = FALSE
	for (var/turf/t in turfs)
		for (var/turf/tt in turfs)
			if (istype(t) && istype(tt))
				maxDistY = max(maxDistY, abs(t.y - tt.y))

	return maxDistY + 1

/proc/min_area_x(var/area/a) //takes an actual area or a type
	var/list/turfs = get_area_turfs(a)
	var/min_x = world.maxx

	for (var/turf/t in turfs)
		if (istype(t))
			min_x = min(min_x, t.x)

	return min_x

/proc/min_area_y(var/area/a)
	var/list/turfs = get_area_turfs(a)
	var/min_y = world.maxy

	for (var/turf/t in turfs)
		if (istype(t))
			min_y = min(min_y, t.y)

	return min_y

/proc/max_area_x(var/area/a) //takes an actual area or a type
	var/list/turfs = get_area_turfs(a)
	var/max_x = FALSE

	for (var/turf/t in turfs)
		if (istype(t))
			max_x = max(max_x, t.x)

	return max_x

/proc/max_area_y(var/area/a)
	var/list/turfs = get_area_turfs(a)
	var/max_y = FALSE

	for (var/turf/t in turfs)
		if (istype(t))
			max_y = max(max_y, t.y)

	return max_y