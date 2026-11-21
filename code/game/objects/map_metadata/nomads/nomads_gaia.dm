
/obj/map_metadata/nomads/gaia
	ID = MAP_NOMADS_GAIA
	// The sun's path (sun_shadows.dm): degrees north.
	sun_latitude = 45
	world_longitude = -30 // world calendar time zone (world_calendar.dm)
	world_region = "gaia" // its id in world_links (weather_shared.dm)
	// z 1 is unformed rock that forms as it is dug (dug_underground.dm).
	underground_compiled_z = 1
	title = "Nomads (Gaia)"
	lobby_icon = 'icons/lobby/gaia_volcano.dmi' // the volcano crater, with drifting embers
	lobby_icon_wide = 'icons/lobby/gaia_volcano_wide.dmi'
	songs = list("In the beginning there was nothing:1" = "sound/music/in_the_beginning.ogg",)
	research_active = TRUE
	// Roofs may add up to four open-air levels: buildings of up to four storeys.
	building_levels = 10
	building_level_standing = TRUE
	// The rock under Gaia's deep ocean (level 1) opens to the sea for submarines.
	sea_layer_surface_z = 2
	// Hills: per-tile heights for the surface (docs/terrain-height.md).
	terrain_height_file = "maps/heights/nomads_gaia.txt"
	// New nomads start at random on the surface (nomads_start.dm); level 1 is underground.
	new_player_start_z = 2

/obj/map_metadata/nomads/gaia/weather_policy_choices(list/possibilities)
	var/list/choices = ..()
	if (weather != WEATHER_NONE || !choices || !(WEATHER_NONE in choices))
		return choices
	// Double the pool with clear slots: halve each natural precipitation start
	// chance without prolonging an existing wet spell or changing other maps.
	var/list/weighted_choices = choices.Copy()
	for (var/i = 1, i <= choices.len, i++)
		weighted_choices += WEATHER_NONE
	return weighted_choices
