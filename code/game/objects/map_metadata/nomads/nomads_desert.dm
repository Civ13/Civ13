
/obj/map_metadata/nomads/desert
	ID = MAP_NOMADS_DESERT
	title = "Nomads (Desert)"
	// Hills: per-tile heights for the surface, z 2 (docs/terrain-height.md).
	terrain_height_file = "maps/heights/nomads_desert.txt"
	description = "Battle on the Nomads (Desert) map."
	ambience = list("sound/ambience/desert.ogg")
	research_active = TRUE
	// Roofs may add up to four open-air levels (building_admission.dm); the
	// first stands from the start of the round so aircraft can fly.
	building_levels = 4
	building_level_standing = TRUE
	// Walk on over the east edge into Asia and the south edge into the
	// Jungle (region_edge.dm), on the surface level.
	edge_crossings = list("east" = "asia", "south" = "jungle")
	edge_crossing_z = 2
	var/real_season = "wet"

/obj/map_metadata/nomads/desert/New()
	..()
	if(!durable_schedule("nomads_initial_climate", 1800))
		spawn(1800)
			if (season == SEASON_SPRING) //fixes game setting the season as spring
				season = SEASON_WET