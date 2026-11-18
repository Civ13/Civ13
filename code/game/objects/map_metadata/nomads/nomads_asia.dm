/obj/map_metadata/nomads/asia
	ID = MAP_NOMADS_ASIA
	// The sun's path (sun_shadows.dm): degrees north.
	sun_latitude = 40
	// Cinnabar on an old mercury belt: twice as common (mercury.dm).
	cinnabar_rich = TRUE
	title = "Nomads (Asia)"
	// Hills: per-tile heights for the surface, z 1 (docs/terrain-height.md).
	terrain_height_file = "maps/heights/nomads_asia.txt"
	description = "After the collapse of the previous civilizations inhabiting this continent, people are starting to form groups and settle down."
	mission_start_message = "<big>After the collapse of the previous civilizations inhabiting this continent, people are starting to form groups and settle down. Will they be able to work together?</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/gamemodes/Civilizations_and_Nomads</b>"
	research_active = TRUE
	// Roofs may add up to four open-air levels (building_admission.dm); the
	// first stands from the start of the round so aircraft can fly.
	building_levels = 10
	building_level_standing = TRUE
	// Walk on over the west edge (region_edge.dm): its northern half runs on
	// into Europe, its southern half over the Sinai into Africa.
	edge_crossings = list("west" = list("africa" = list(0, 0.5), "europe" = list(0.5, 1)))
	// Mined-out mountain floor keeps giving stone and regrowing ore seams
	// (mountain_seams.dm), and a tunnel dug down opens a cave level
	// (dug_underground.dm).
	mountain_seams = TRUE
	// Black iron sand on its coasts and rivers (tatara.dm).
	iron_sand_rich = TRUE
	dig_down_underground = TRUE

/obj/map_metadata/nomads/asia/season_transition_complete(var/epoch)
	..(epoch)
	if (!season_worker_valid(epoch))
		return
	var/season_work = 0
	if (season ==  "SUMMER" || season == "FALL")
		for (var/turf/floor/beach/water/flooded/DF in season_world_candidates(/turf/floor/beach/water/flooded, epoch)) // Directly change, you have no Z levels on your map
			if (!season_work_pause(epoch, ++season_work))
				return
			if (!season_candidate_valid(DF, /turf/floor/beach/water/flooded))
				continue
			DF.ChangeTurf(/turf/floor/dirt/flooded)
	else
		for (var/turf/floor/dirt/flooded/DF in season_world_candidates(/turf/floor/dirt/flooded, epoch)) // Directly change, you have no Z levels on your map
			if (!season_work_pause(epoch, ++season_work))
				return
			if (!season_candidate_valid(DF, /turf/floor/dirt/flooded))
				continue
			DF.ChangeTurf(/turf/floor/beach/water/flooded)
