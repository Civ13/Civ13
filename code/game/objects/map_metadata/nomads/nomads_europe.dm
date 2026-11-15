
/obj/map_metadata/nomads/europe
	ID = MAP_NOMADS_EUROPE
	title = "Nomads (Europe)"
	// Hills: per-tile heights for the surface, z 1 (docs/terrain-height.md).
	terrain_height_file = "maps/heights/nomads_europe.txt"
	description = "Battle on the Nomads (Europe) map."
	research_active = TRUE
	dig_down_underground = TRUE
	// Roofs may add up to four open-air levels beside the dug cave
	// (building_admission.dm); the first stands from the start of the round so
	// aircraft can fly.
	building_levels = 4
	building_level_standing = TRUE
	// Walk on over the east edge into Asia (region_edge.dm).
	edge_crossings = list("east" = "asia")
