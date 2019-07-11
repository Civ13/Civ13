#define NO_WINNER "The battle is still going on."
/obj/map_metadata/khalkhyn
	ID = MAP_KHALKHYN_GOL
	title = "Khalkhyn Gol (90x200x1)"
	lobby_icon_state = "ww2"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 1200
	squad_spawn_locations = FALSE
	faction_organization = list(
		JAPANESE,
		RUSSIAN)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/russian/land/inside/command,
		list(JAPANESE) = /area/caribbean/japanese/land/inside/command,
		)
	age = "1939"
	ordinal_age = 6
	faction_distribution_coeffs = list(JAPANESE = 0.5, RUSSIAN = 0.5)
	battle_name = "battle of Khalkhyn Gol"
	mission_start_message = "<font size=4>All factions have <b>8 minutes</b> to prepare before the ceasefire ends!<br>The Japanese will win if they capture the <b>Soviet command</b>. The Soviets will win if they manage to capture the <b>Japanese command</b>.</font>"
	faction1 = JAPANESE
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_RAIN)
	songs = list(
		"Neue Deutsche Welle (Remix):1" = 'sound/music/neue_deutsche_welle.ogg',)

/obj/map_metadata/khalkhyn/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_ww2 == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/khalkhyn/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)

/obj/map_metadata/khalkhyn/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)


/obj/map_metadata/khalkhyn/roundend_condition_def2name(define)
	..()
	switch (define)
		if (JAPANESE)
			return "Japanese"
		if (RUSSIAN)
			return "Soviet"
/obj/map_metadata/khalkhyn/roundend_condition_def2army(define)
	..()
	switch (define)
		if (JAPANESE)
			return "Japanese"
		if (RUSSIAN)
			return "Soviets"

/obj/map_metadata/khalkhyn/army2name(army)
	..()
	switch (army)
		if ("Japanese")
			return "Japanese"
		if ("Soviets")
			return "Soviet"


/obj/map_metadata/khalkhyn/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The Soviets may now cross the invisible wall!</font>"
	else if (faction == JAPANESE)
		return "<font size = 4>The Japanese may now cross the invisible wall!</font>"

/obj/map_metadata/khalkhyn/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Soviets may no longer cross the invisible wall!</span>"
	else if (faction == JAPANESE)
		return "<span class = 'userdanger'>The Japanese may no longer cross the invisible wall!</span>"

	#undef NO_WINNER