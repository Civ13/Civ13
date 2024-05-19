/obj/map_metadata/landing_at_constantinopoli
	ID = MAP_CONSTANTINOPOLI
	title = "Landing at Constantinopoli"
	lobby_icon = "icons/lobby/ancient.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 0
	no_hardcore = TRUE
	victory_time = 24000

	faction_organization = list(
		ROMAN,
		RUSSIAN)

	roundend_condition_sides = list(
		list(ROMAN) = /area/caribbean/british/land/outside/objective,
		list(RUSSIAN) = /area/caribbean/german,
		)
	age = "2009"
	ordinal_age = 8
	faction_distribution_coeffs = list(ROMAN = 0.4, RUSSIAN = 0.6)
	battle_name = "Landing at Constantinopoli"
	mission_start_message = "<font size=4>All factions have <b>8 minutes</b> to prepare before the battle begins!<br>The Latin Empire will win if they hold out for <b>40 minutes</b>. The Russians will win if they manage to enter the city!</font>"
	faction1 = ROMAN
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Crusaders:1" = 'sound/music/crusaders.ogg')
	gamemode = "Siege"
	fob_spawns = TRUE
	no_hardcore = TRUE
	var/faction2_flag = "russian"

/obj/map_metadata/landing_at_constantinopoli/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_grozny == TRUE)
		. = TRUE
	else if (J.is_latin == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/landing_at_constantinopoli/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)

/obj/map_metadata/landing_at_constantinopoli/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 26000 || admin_ended_all_grace_periods)

/obj/map_metadata/landing_at_constantinopoli/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/landing_at_constantinopoli/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/landing_at_constantinopoli/roundend_condition_def2name(define)
	..()
	switch (define)
		if (ROMAN)
			return "Latin Empire"
		if (RUSSIAN)
			return "Russian"
/obj/map_metadata/landing_at_constantinopoli/roundend_condition_def2army(define)
	..()
	switch (define)
		if (ROMAN)
			return "Latin Empire"
		if (RUSSIAN)
			return "Russian"

/obj/map_metadata/landing_at_constantinopoli/army2name(army)
	..()
	switch (army)
		if ("Romans")
			return "Latin Empire"
		if ("Russians")
			return "Russian"


/obj/map_metadata/landing_at_constantinopoli/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The Russians may now cross the invisible wall!</font>"
	else if (faction == ROMAN)
		return ""
	else
		return ""

/obj/map_metadata/landing_at_constantinopoli/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Russians may no longer cross the invisible wall!</span>"
	else if (faction == ROMAN)
		return ""
	else
		return ""


/obj/map_metadata/landing_at_constantinopoli/update_win_condition()

	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Latin Empire</b> has successfully defended the city! The Russians have halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_o == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Russians</b> have captured the city! The Landing at Constantinopoli is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_o = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Russians</b> have captured the city! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Russians</b> have captured the city! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Russians</b> have captured the city! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Russians</b> have captured the city! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Latin Empire</b> has recaptured the city!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE