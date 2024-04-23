
/obj/map_metadata/nomads_mountain
	no_winner ="The round is proceeding normally."
	ID = MAP_NOMADS_MOUNTAIN
	title = "Nomads (Mountain)"
	lobby_icon = 'icons/lobby/civilizations.gif'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	has_hunger = TRUE

	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "5000 B.C."
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big>Your people has lived in the mountains for ages. Now, its time to expand and dig deeper, but as your ancestors always said, the deeper you dig, the more dangerous it gets...</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Classic (Stone Age Start)"
	var/real_season = "wet"
/obj/map_metadata/nomads_mountain/New()
	..()
	spawn(1800)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"
	spawn(18000)
		seasons()

/obj/map_metadata/nomads_mountain/cross_message(faction)
	return ""

/obj/map_metadata/nomads_mountain/seasons()
	if (real_season == "dry")
		season = "Wet Season"
		world << "<big>The <b>Wet Season</b> has started.</big>"
		change_weather_somehow()
		for (var/turf/floor/beach/drywater/D)
			D.ChangeTurf(/turf/floor/beach/water/swamp)
		real_season = "wet"
	else
		season = "Dry Season"
		world << "<big>The <b>Dry Season</b> has started.</big>"
		change_weather_somehow()
		for (var/turf/floor/beach/water/swamp/D)
			D.ChangeTurf(/turf/floor/beach/drywater)
		real_season = "dry"

	spawn(18000)
		seasons()


/obj/map_metadata/nomads_mountain/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE
