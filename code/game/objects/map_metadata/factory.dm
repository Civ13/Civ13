/obj/map_metadata/factory
	ID = MAP_FACTORY
	title = "Factory"
	lobby_icon_state = "coldwar"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle,/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two,/area/caribbean/no_mans_land/invisible_wall/inside)
	respawn_delay = 300


	faction_organization = list(
		CIVILIAN,
		RUSSIAN)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/japanese/land/inside/command,
		list(RUSSIAN) = /area/caribbean/russian/land/inside/command
		)
	age = "2021"
	ordinal_age = 8
	faction_distribution_coeffs = list(CIVILIAN = 0.5, RUSSIAN = 0.5)
	battle_name = "battle for the factory"
	mission_start_message = "<font size=4>The <b>Ukrainian Ground Force</b> must defend their front line from the Russian Advance. The <b>Russian Federal Forces</b> must defend their base.<br>All factions have <b>5 minutes</b> to prepare before the combat starts.</font>"
	faction1 = CIVILIAN
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Kino - I Want Changes:1" = 'sound/music/want_changes.ogg',)
	artillery_count = 0

obj/map_metadata/road_to_dak_to/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian/ukrainian))
		if (J.is_ukrainerussowar)
			. = TRUE
		else
			. = FALSE
	if (istype(J, /datum/job/russian))
		if (J.is_ukrainerussowar && !J.is_rusretreat && J.is_modernday)
			. = TRUE
		else
			. = FALSE

/obj/map_metadata/road_to_dak_to/cross_message(faction)
	return "<font size = 4>All factions may cross the grace wall now!</font>"

/obj/map_metadata/road_to_dak_to/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/road_to_dak_to/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/road_to_dak_to/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/inside))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE