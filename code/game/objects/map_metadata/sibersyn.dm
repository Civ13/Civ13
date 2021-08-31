
/obj/map_metadata/sibersyn
	ID = MAP_SIBERSYN
	title = "sibersyn"
	lobby_icon_state = "ww1"
	no_winner ="The battle ends in stalemate."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 600
	faction_organization = list(
		RUSSIAN,
		CIVILIAN)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/pirates/land/inside/objective,
		list(CIVILIAN) = /area/caribbean/russian/land/inside/command,
		)
	age = "1919"
	ordinal_age = 5
	faction_distribution_coeffs = list(RUSSIAN = 0.5, CIVILIAN = 0.5)
	battle_name = "battle of the bridge"
	mission_start_message = "<font size=4>All factions have <b>7 minutes</b> to prepare before the ceasefire ends!<br>The <b>Soviets</b> will win if they capture the enemy outpost <b>in 40 minutes</b>. The <b>White Army</b> will win if they capture the enemy outpost<b> if no base gets captured within 40 minutes,the battle will end in a stalemate</font>"
	faction1 = RUSSIAN
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	ordinal_age = 5
	songs = list(
		"Argonnerwaldlied:1" = 'sound/music/argonnerwaldlied.ogg')
	gamemode = "Siege"
obj/map_metadata/sibersyn/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian/fantasy))
		. = FALSE
	if (istype(J, /datum/job/russian))
		if (J.is_rcw == TRUE)
			. = TRUE
		else
			. = FALSE
	else
		if (J.is_rcw == TRUE)
			. = TRUE
		else
			. = FALSE

/obj/map_metadata/sibersyn/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4200 || admin_ended_all_grace_periods)

/obj/map_metadata/sibersyn/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4200 || admin_ended_all_grace_periods)


/obj/map_metadata/sibersyn/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "White"
		if (CIVILIAN)
			return "Soviet"
/obj/map_metadata/sibersyn/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Whites"
		if (CIVILIAN)
			return "Soviets"

/obj/map_metadata/sibersyn/army2name(army)
	..()
	switch (army)
		if ("Whites")
			return "White"
		if ("Soviets")
			return "Soviet"


/obj/map_metadata/sibersyn/cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 4>The Red Army may now cross the invisible wall!</font>"
	else if (faction == RUSSIAN)
		return "<font size = 4>The White Army may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/sibersyn/reverse_cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 4>The Red Army may no longer cross the invisible wall!</font>"
	else if (faction == RUSSIAN)
		return "<font size = 4>The White Army may no longer cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/berlin/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/berlin/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/sibersyn/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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