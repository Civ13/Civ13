/datum/turf_initializer/proc/initialize(var/turf/T)
	return

/area
	var/datum/turf_initializer/turf_initializer = null

/area/proc/initialize()
	for (var/turf/T in src)
		T.initialize()
		if (turf_initializer)
			turf_initializer.initialize(T)
