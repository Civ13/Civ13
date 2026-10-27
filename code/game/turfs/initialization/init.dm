/datum/turf_initializer/proc/initialize(var/turf/T)
	return

/area
	var/datum/turf_initializer/turf_initializer = null

/area/proc/initialize(datum/persistence_area_startup/startup)
#ifdef CIV13_ZONE_PERSISTENCE
	var/datum/persistence_area_registry_epoch/registry_epoch = persistence_area_epoch
	if(startup) startup.require_owner()
	else require_persistence_area_snapshot(registry_epoch)
#endif
	for (var/turf/T in src)
#ifdef CIV13_ZONE_PERSISTENCE
		if(startup) startup.require_owner()
		else require_persistence_area_snapshot(registry_epoch)
#endif
		T.initialize()
#ifdef CIV13_ZONE_PERSISTENCE
		if(startup) startup.require_owner()
		else require_persistence_area_snapshot(registry_epoch)
#endif
		if (turf_initializer)
			turf_initializer.initialize(T)
#ifdef CIV13_ZONE_PERSISTENCE
			if(startup) startup.require_owner()
			else require_persistence_area_snapshot(registry_epoch)
#endif
