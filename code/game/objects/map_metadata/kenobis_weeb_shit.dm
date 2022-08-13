
/obj/map_metadata/kenobi_weeb_shit
	ID = MAP_KENOBI
	title = "Kenobi's Test Map"
	no_winner ="The round is proceeding normally."
	lobby_icon = "icons/lobby/ww2.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 1200 // 10 minutes!


	faction_organization = list(
		JAPANESE,)

	roundend_condition_sides = list(
		list(JAPANESE) = /area/caribbean/british
		)
	age = "1943"
	civilizations = FALSE
	faction_distribution_coeffs = list(JAPANESE = 1)
	battle_name = ""
	mission_start_message = "Kenobi go'na test the fek outta ya"
	ambience = list('sound/ambience/desert.ogg')
	faction1 = JAPANESE
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Kenobi's Testing"
	ordinal_age = 6
	default_research = 152
	research_active = FALSE
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE
	age7_done = FALSE
	age8_done = FALSE

/obj/map_metadata/kenobi_weeb_shit/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_ww2 == TRUE && J.is_tanker == TRUE)
		. = TRUE
	else
		. = FALSE