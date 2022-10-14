/obj/map_metadata/karelia
	ID = MAP_KARELIA
	title = "Karelia"
	lobby_icon = "icons/lobby/karelia.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/taiga)
	respawn_delay = 1200
	no_hardcore = TRUE
	faction_organization = list(
		RUSSIAN,
		FINNISH)
	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/russian/,
		list(FINNISH) = /area/caribbean/german/,
		)
	age = "1943"
	ordinal_age = 6
	faction_distribution_coeffs = list(FINNISH = 0.5, RUSSIAN = 0.5)
	battle_name = "Battle for Karelia"
	mission_start_message = "<font size=4>All factions have <b>6 minutes</b> to prepare before the ceasefire ends!<br><br>The Soviet Army has to capture the Warehouse North-East of the region.<br><br>The Finnish Army has to capture the Soviet HQ South-West of the region!</font>"
	faction1 = FINNISH
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	grace_wall_timer = 3600
	songs = list(
		"Red Army Choir - Katyusha:1" = "sound/music/katyusha.ogg",)

/obj/map_metadata/karelia/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_karelia == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/karelia/roundend_condition_def2name(define)
	..()
	switch (define)
		if (FINNISH)
			return "Finnish"
		if (RUSSIAN)
			return "Soviet"
/obj/map_metadata/karelia/roundend_condition_def2army(define)
	..()
	switch (define)
		if (FINNISH)
			return "Finnish"
		if (RUSSIAN)
			return "Soviets"

/obj/map_metadata/karelia/army2name(army)
	..()
	switch (army)
		if ("Finnish")
			return "Finnish"
		if ("Soviets")
			return "Soviet"

/obj/map_metadata/karelia/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The Soviets may now cross the invisible wall!</font>"
	else if (faction == FINNISH)
		return "<font size = 4>The Finnish may now cross the invisible wall!</font>"

/obj/map_metadata/karelia/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Soviets may no longer cross the invisible wall!</span>"
	else if (faction == FINNISH)
		return "<span class = 'userdanger'>The Finnish may no longer cross the invisible wall!</span>"