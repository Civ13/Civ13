
/proc/explosion(turf/epicenter, devastation_range, heavy_impact_range, light_impact_range, flash_range, adminlog = TRUE, z_transfer = UP|DOWN, is_rec = config.use_recursive_explosions)
/*
	// TODO: splits explosions bigger than 5x5 into sub-explosions
	var/num_explosions = devastation_range/5
	var/explosion_epicenters_locations = list()

	for (var/v in 1 to num_explosions)
		// do data for first explosion
		// epicenter = locate(epicenter.x+devestation_range)

*/
	src = null	//so we don't abort once src is deleted
	var/datum/explosiondata/data = new
	data.epicenter = epicenter
	data.devastation_range = devastation_range
	data.heavy_impact_range = heavy_impact_range
	data.light_impact_range = light_impact_range
	data.flash_range = flash_range
	data.adminlog = adminlog
	data.z_transfer = z_transfer
	data.is_rec = is_rec
	data.rec_pow = max(0,devastation_range) * 2 + max(0,heavy_impact_range) + max(0,light_impact_range)

	// queue work
	processes.callproc.queue(processes.explosion, /process/explosion/proc/queue, list(data), 1)

	return data

/obj
	var/explosion_resistance

/turf
	var/explosion_resistance

/turf/floor
	explosion_resistance = TRUE

/turf/wall
	explosion_resistance = 10