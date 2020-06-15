
/obj/map_metadata/road_to_dak_to
	ID = MAP_ROAD_TO_DAK_TO
	title = "Road to Dak To"
	lobby_icon_state = "coldwar"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle)
	respawn_delay = 300


	faction_organization = list(
		AMERICAN,
		VIETNAMESE)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/british,
		list(VIETNAMESE) = /area/caribbean/japanese
		)
	age = "1969"
	ordinal_age = 7
	faction_distribution_coeffs = list(AMERICAN = 0.5, VIETNAMESE = 0.5)
	battle_name = "battle for the road"
	mission_start_message = "<font size=4>The <b>Vietcong</b> must defend the village from the Americans. The <b>US Army</b> must defend their base.<br>All factions have <b>5 minutes</b> to prepare before the combat starts.</font>"
	faction1 = AMERICAN
	faction2 = VIETNAMESE
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Fortunate Son:1" = 'sound/music/fortunate_son.ogg',)
	artillery_count = 3

obj/map_metadata/road_to_dak_to/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_coldwar == TRUE && !J.is_specops && !J.is_modernday)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/road_to_dak_to/cross_message(faction)
	return "<font size = 4>All factions may cross the grace wall now!</font>"

/obj/map_metadata/road_to_dak_to/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/road_to_dak_to/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

