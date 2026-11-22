// The ocean regions (docs/ocean-regions.md): one level of open sea between the
// lands of the earth group. The ocean area, the breakers turf and ocean_world()
// are in code/modules/naval/ocean_regions.dm; the maps are written by
// tools/ocean_maps/generate.py from tools/world_links/world_links.json.
// The base type is abstract: each ocean names its own map ID.
/obj/map_metadata/nomads/ocean
	title = "The Open Ocean"
	description = "Open water between the lands. Ships cross it from one coast to another."
	battle_name = "open ocean"
	mission_start_message = "<big>Open water in every direction. Sail on to the coasts beyond the horizon.</big>"
	research_active = TRUE
	// Nothing grows and nothing is dug, built upward or raised in hills here.
	dig_down_underground = FALSE
	building_levels = 0
	ecology_wildlife_cap = 0
	wild_plant_cap = 0
	sea_life_cap = 60
	new_player_start_z = 1
	// The ocean id in the world links table.
	var/ocean = null

/obj/map_metadata/nomads/ocean/atlantic
	ID = MAP_NOMADS_OCEAN_ATLANTIC
	title = "The Atlantic Ocean"
	ocean = "atlantic"
	sun_latitude = 30
	world_longitude = -30 // world calendar time zone (world_calendar.dm)
	world_region = "atlantic" // its id in world_links (weather_shared.dm)

/obj/map_metadata/nomads/ocean/pacific
	ID = MAP_NOMADS_OCEAN_PACIFIC
	title = "The Pacific Ocean"
	ocean = "pacific"
	sun_latitude = 15
	world_longitude = -165 // world calendar time zone (world_calendar.dm)
	world_region = "pacific" // its id in world_links (weather_shared.dm)

/obj/map_metadata/nomads/ocean/indian
	ID = MAP_NOMADS_OCEAN_INDIAN
	title = "The Indian Ocean"
	ocean = "indian"
	sun_latitude = -15
	world_longitude = 75 // world calendar time zone (world_calendar.dm)
	world_region = "indian" // its id in world_links (weather_shared.dm)

/obj/map_metadata/nomads/ocean/arctic
	ID = MAP_NOMADS_OCEAN_ARCTIC
	title = "The Arctic Ocean"
	ocean = "arctic"
	sun_latitude = 78
	world_longitude = 0 // world calendar time zone (world_calendar.dm)
	world_region = "arctic" // its id in world_links (weather_shared.dm)
	sea_life_cap = 30

/obj/map_metadata/nomads/ocean/southern
	ID = MAP_NOMADS_OCEAN_SOUTHERN
	title = "The Southern Ocean"
	ocean = "southern"
	sun_latitude = -60
	world_longitude = 0 // world calendar time zone (world_calendar.dm)
	world_region = "southern" // its id in world_links (weather_shared.dm)
	sea_life_cap = 40
