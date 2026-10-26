//Takes: Area type as text string or as typepath OR an instance of the area.
//Returns: A list of all turfs in areas of that type in the world.
//Optional turf_type restricts the fresh snapshot before allocating its entries.
/proc/get_area_turfs(var/areatype, var/list/predicates, var/turf_type, var/obj/map_metadata/season_owner, var/season_epoch)
#ifdef CIV13_ZONE_PERSISTENCE
	require_persistence_area_registry()
	var/datum/persistence_area_registry_epoch/registry_epoch = persistence_area_epoch
#endif
	if (!areatype) return null
	else if (istext(areatype)) areatype = text2path(areatype)
	else if (isarea(areatype))
		var/area/areatemp = areatype
		areatype = areatemp.type

	var/list/turfs = list()
	var/season_work = 0
	for (var/area/A in area_list)
#ifdef CIV13_ZONE_PERSISTENCE
		require_persistence_area_registry()
#endif
		if (season_owner && !season_owner.season_work_pause(season_epoch, ++season_work, TRUE))
			return null
#ifdef CIV13_ZONE_PERSISTENCE
		require_persistence_area_snapshot(registry_epoch)
#endif
		if (istype(A, areatype))
			if (!season_owner)
				if (!turf_type)
					for (var/turf/T in A.contents)
#ifdef CIV13_ZONE_PERSISTENCE
						var/accepted = persistence_area_predicates_true(T, predicates, registry_epoch)
#else
						var/accepted = !predicates || all_predicates_true(list(T), predicates)
#endif
#ifdef CIV13_ZONE_PERSISTENCE
						require_persistence_area_snapshot(registry_epoch)
#endif
						if (accepted)
							turfs += T
					continue
				for (var/turf/T in A.contents)
					if (!istype(T, turf_type))
						continue
#ifdef CIV13_ZONE_PERSISTENCE
					var/accepted = persistence_area_predicates_true(T, predicates, registry_epoch)
#else
					var/accepted = !predicates || all_predicates_true(list(T), predicates)
#endif
#ifdef CIV13_ZONE_PERSISTENCE
					require_persistence_area_snapshot(registry_epoch)
#endif
					if (accepted)
						turfs += T
				continue
			for (var/turf/T in A.contents)
				season_work++
				if (!(season_work % 64) && !season_owner.season_work_pause(season_epoch, season_work, TRUE))
					return null
#ifdef CIV13_ZONE_PERSISTENCE
				require_persistence_area_snapshot(registry_epoch)
#endif
				if (turf_type && !istype(T, turf_type))
					continue
#ifdef CIV13_ZONE_PERSISTENCE
				var/accepted = persistence_area_predicates_true(T, predicates, registry_epoch)
#else
				var/accepted = !predicates || all_predicates_true(list(T), predicates)
#endif
#ifdef CIV13_ZONE_PERSISTENCE
				require_persistence_area_snapshot(registry_epoch)
#endif
				if (accepted)
					turfs += T
	if (season_owner && !season_owner.season_worker_valid(season_epoch))
		return null
	return turfs

/proc/pick_area_turf(var/areatype, var/list/predicates)
	var/list/turfs = get_area_turfs(areatype, predicates)
	if (turfs && turfs.len)
		return pick(turfs)

#ifdef CIV13_ZONE_PERSISTENCE
/proc/persistence_area_predicates_true(turf/T, list/predicates, datum/persistence_area_registry_epoch/epoch)
	require_persistence_area_snapshot(epoch)
	if(!predicates) return TRUE
	functional_sanity(list(T), predicates)
	var/list/callbacks = predicates.Copy()
	for(var/i = 1, i <= callbacks.len, i++)
		require_persistence_area_snapshot(epoch)
		var/accepted = call(callbacks[i])(T)
		require_persistence_area_snapshot(epoch)
		if(!accepted) return FALSE
	return TRUE
#endif
