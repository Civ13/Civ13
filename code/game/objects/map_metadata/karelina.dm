/obj/map_metadata/karelina
	ID = MAP_KARELINA
	title = "Karelina"
	lobby_icon_state = "ww2"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/taiga)
	respawn_delay = 1200

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
	battle_name = "Battle of Karelina"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!<br></font>"
	faction1 = FINNISH
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Neue Deutsche Welle (Remix):1" = 'sound/music/neue_deutsche_welle.ogg',)

/obj/map_metadata/karelina/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_karelina == TRUE)
		. = TRUE
	else
		. = FALSE


/obj/map_metadata/karelina/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/karelina/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/karelina/roundend_condition_def2name(define)
	..()
	switch (define)
		if (FINNISH)
			return "Finnish"
		if (RUSSIAN)
			return "Soviet"
/obj/map_metadata/karelina/roundend_condition_def2army(define)
	..()
	switch (define)
		if (FINNISH)
			return "Finnish"
		if (RUSSIAN)
			return "Soviets"

/obj/map_metadata/karelina/army2name(army)
	..()
	switch (army)
		if ("Finnish")
			return "Finnish"
		if ("Soviets")
			return "Soviet"

/obj/map_metadata/karelina/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The Soviets may now cross the invisible wall!</font>"
	else if (faction == FINNISH)
		return "<font size = 4>The Finnish may now cross the invisible wall!</font>"

/obj/map_metadata/karelina/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Soviets may no longer cross the invisible wall!</span>"
	else if (faction == FINNISH)
		return "<span class = 'userdanger'>The Finnish may no longer cross the invisible wall!</span>"