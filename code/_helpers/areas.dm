//Takes: Area type as text string or as typepath OR an instance of the area.
//Returns: A list of all turfs in areas of that type in the world.
//Optional turf_type restricts the fresh snapshot before allocating its entries.
/proc/get_area_turfs(var/areatype, var/list/predicates, var/turf_type, var/obj/map_metadata/season_owner, var/season_epoch)
	if (!areatype) return null
	else if (istext(areatype)) areatype = text2path(areatype)
	else if (isarea(areatype))
		var/area/areatemp = areatype
		areatype = areatemp.type

	var/list/turfs = list()
	var/season_work = 0
	for (var/area/A in area_list)
		if (season_owner && !season_owner.season_work_pause(season_epoch, ++season_work, TRUE))
			return null
		if (istype(A, areatype))
			if (!season_owner)
				if (!turf_type)
					for (var/turf/T in A.contents)
						if (!predicates || all_predicates_true(list(T), predicates))
							turfs += T
					continue
				for (var/turf/T in A.contents)
					if (!istype(T, turf_type))
						continue
					if (!predicates || all_predicates_true(list(T), predicates))
						turfs += T
				continue
			for (var/atom/candidate in A.contents)
				if (season_owner && !season_owner.season_work_pause(season_epoch, ++season_work, TRUE))
					return null
				if (!isturf(candidate))
					continue
				var/turf/T = candidate
				if (turf_type && !istype(T, turf_type))
					continue
				if (!predicates || all_predicates_true(list(T), predicates))
					turfs += T
	return turfs

/proc/pick_area_turf(var/areatype, var/list/predicates)
	var/list/turfs = get_area_turfs(areatype, predicates)
	if (turfs && turfs.len)
		return pick(turfs)
