
/obj/map_metadata/nomads/jungle
	ID = MAP_NOMADS_JUNGLE
	title = "Nomads (Jungle)"
	// Hills: per-tile heights for the surface, z 2 (docs/terrain-height.md).
	terrain_height_file = "maps/heights/nomads_jungle.txt"
	description = "Battle on the Nomads (Jungle) map."
	research_active = TRUE
	// Roofs may add up to four open-air levels (building_admission.dm); the
	// first stands from the start of the round so aircraft can fly.
	building_levels = 4
	building_level_standing = TRUE
	// Walk on over the north edge into the Desert (region_edge.dm), on the
	// surface level.
	edge_crossings = list("north" = "desert")
	edge_crossing_z = 2

	var/real_season = "wet"

/obj/map_metadata/nomads/jungle/New()
	..()
	if(!durable_schedule("nomads_initial_climate", 1800))
		spawn(1800)
			if (season == SEASON_SPRING) //fixes game setting the season as spring
				season = SEASON_WET