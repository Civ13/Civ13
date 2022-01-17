
/obj/map_metadata/african_warlords
	ID = MAP_AFRICAN_WARLORDS
	title = "African Warlords"
	lobby_icon_state = "coldwar"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle,/area/caribbean/no_mans_land/invisible_wall/jungle/one,/area/caribbean/no_mans_land/invisible_wall/jungle/two,/area/caribbean/no_mans_land/invisible_wall/jungle/three)
	respawn_delay = 300
	no_winner ="No warband has won yet."
	lobby_icon_state = "africanwarlords"
	faction_organization = list(INDIANS)

	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/british,
		)
	age = "1984"
	is_singlefaction = TRUE
	ordinal_age = 7
	faction_distribution_coeffs = list(INDIANS = 1)
	battle_name = "skull competition"
	mission_start_message = "<font size=4>Three African warlords are fighting for the control of this area. They will need to collect <b>50 enemy skulls</b> and bring them to their shaman hut.</font>"
	faction1 = INDIANS
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Fortunate Son:1" = 'sound/music/fortunate_son.ogg',)

obj/map_metadata/african_warlords/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_warlords && J.title != "warlord (do not use)")
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/african_warlords/cross_message(faction)
	return "<font size = 4>All factions may cross the grace wall now!</font>"

/obj/map_metadata/african_warlords/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/african_warlords/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/african_warlords/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle/one))
			if (H.nationality == "Redkantu")
				return TRUE
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle/two))
			if (H.nationality == "Blugisi")
				return TRUE
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle/three))
			if (H.nationality == "Yellowagwana")
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE
