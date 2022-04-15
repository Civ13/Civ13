/obj/map_metadata/hue
	ID = MAP_HUE
	title = "Hue"
	lobby_icon_state = "coldwar"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 300
	no_winner ="No base has been captured."


	faction_organization = list(
		AMERICAN,
		VIETNAMESE)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/british,
		list(VIETNAMESE) = /area/caribbean/japanese
		)
	age = "1969"
	ordinal_age = 7
	faction_distribution_coeffs = list(AMERICAN = 0.4, VIETNAMESE = 0.6)
	battle_name = "jungle compound"
	mission_start_message = "<font size=4>The <b>NVA</b> must defend their base from the Americans. The <b>US Army</b> must defend their base.<br>All factions have <b>5 minutes</b> to prepare before the combat starts.</font>"
	faction1 = AMERICAN
	faction2 = VIETNAMESE
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Fortunate Son:1" = "sound/music/fortunate_son.ogg",)
	artillery_count = 8

/obj/map_metadata/hue/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/vietnamese))
		if (J.is_vietcong)
			. = FALSE
		else
			. = TRUE
	else if (istype(J, /datum/job/american))
		if (J.is_coldwar && !J.is_specops && !J.is_modernday)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/hue/cross_message(faction)
	return "<font size = 4>All factions may cross the grace wall now!</font>"

/obj/map_metadata/hue/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/hue/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/hue/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE