/obj/map_metadata/nomads/asia
	ID = MAP_NOMADS_ASIA
	title = "Nomads (Asia)"
	description = "After the collapse of the previous civilizations inhabiting this continent, people are starting to form groups and settle down."
	mission_start_message = "<big>After the collapse of the previous civilizations inhabiting this continent, people are starting to form groups and settle down. Will they be able to work together?</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/gamemodes/Civilizations_and_Nomads</b>"
	research_active = TRUE

/obj/map_metadata/nomads/asia/season_transition_complete(var/epoch)
	..(epoch)
	if (!season_worker_valid(epoch))
		return
	var/season_work = 0
	if (season ==  "SUMMER" || season == "FALL")
		var/list/DF_sweep = season_world_candidates(/turf/floor/beach/water/flooded, epoch) // Directly change, you have no Z levels on your map
		for (var/DF_index = 1, DF_index <= length(DF_sweep), DF_index++)
			var/turf/floor/beach/water/flooded/DF = DF_sweep[DF_index]
			if (!istype(DF))
				continue
			if (!season_work_pause(epoch, ++season_work))
				return
			if (!season_candidate_valid(DF, /turf/floor/beach/water/flooded))
				continue
			DF.ChangeTurf(/turf/floor/dirt/flooded)
	else
		var/list/DF_sweep = season_world_candidates(/turf/floor/dirt/flooded, epoch) // Directly change, you have no Z levels on your map
		for (var/DF_index = 1, DF_index <= length(DF_sweep), DF_index++)
			var/turf/floor/dirt/flooded/DF = DF_sweep[DF_index]
			if (!istype(DF))
				continue
			if (!season_work_pause(epoch, ++season_work))
				return
			if (!season_candidate_valid(DF, /turf/floor/dirt/flooded))
				continue
			DF.ChangeTurf(/turf/floor/beach/water/flooded)
