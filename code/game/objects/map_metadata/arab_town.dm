#define NO_WINNER "The operation is still underway."
/obj/map_metadata/arab_town
	ID = MAP_ARAB_TOWN
	title = "Arab Town (100x100x1)"
	lobby_icon_state = "modern"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 1200
	squad_spawn_locations = FALSE
	min_autobalance_players = 100
	faction_organization = list(
		AMERICAN,
		ARAB)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/british,
		list(ARAB) = /area/caribbean/arab
		)
	age = "2007"
	ordinal_age = 8
	faction_distribution_coeffs = list(AMERICAN = 0.4, ARAB = 0.6)
	battle_name = "battle for the town"
	mission_start_message = "<font size=4>The <b>Hezbollah</b> is holding the town. <b>IDF</b> troops must capture it within 30 minutes!</font>"
	faction1 = AMERICAN
	faction2 = ARAB
	valid_weather_types = list(WEATHER_NONE, WEATHER_SANDSTORM)
	songs = list(
		"Qom Nasheed:1" = 'sound/music/qom_nasheed.ogg',)
	artillery_count = 3
	valid_artillery = list("Explosive")
obj/map_metadata/arab_town/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_modernday == TRUE && istype(J, /datum/job/american/idf))
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/arab_town/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 30000 || admin_ended_all_grace_periods)

/obj/map_metadata/arab_town/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


/obj/map_metadata/arab_town/roundend_condition_def2name(define)
	..()
	switch (define)
		if (ARAB)
			return "Hezbollah"
		if (AMERICAN)
			return "IDF"
/obj/map_metadata/arab_town/roundend_condition_def2army(define)
	..()
	switch (define)
		if (ARAB)
			return "Hezbollah"
		if (AMERICAN)
			return "Israelis"

/obj/map_metadata/arab_town/army2name(army)
	..()
	switch (army)
		if ("Hezbollah")
			return "Hezbollah"
		if ("Israelis")
			return "IDF"


/obj/map_metadata/arab_town/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The IDF may now cross the invisible wall!</font>"
	else if (faction == ARAB)
		return ""
	else
		return ""

/obj/map_metadata/arab_town/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The IDF may no longer cross the invisible wall!</span>"
	else if (faction == ARAB)
		return ""
	else
		return ""

#undef NO_WINNER