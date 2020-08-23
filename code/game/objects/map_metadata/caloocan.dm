/obj/map_metadata/caloocan
	ID = MAP_CALOOCAN
	title = "Caloocan"
	lobby_icon_state = "ph_us_war"
	no_winner ="The church is under Filipino control."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 600

	faction_organization = list(
		FILIPINO,
		AMERICAN)

	roundend_condition_sides = list(
		list(FILIPINO) = /area/caribbean/british,
		list(AMERICAN) = /area/caribbean/russian/land/inside/command,
		)
	age = "1899"
	ordinal_age = 5
	faction_distribution_coeffs = list(FILIPINO = 0.6, AMERICAN = 0.4)
	battle_name = "battle of caloocan"
	mission_start_message = "<font size=4>All factions have <b>7 minutes</b> to prepare before the ceasefire ends!<br>The <b>Soviets</b> will win if they hold out for <b>40 minutes</b>. The <b>White Army</b> will win if they manage to capture the centre of the church.</font>"
	faction1 = FILIPINO
	faction2 = AMERICAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	gamemode = "Siege"
/obj/map_metadata/caloocan/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_ph_us_war == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/caloocan/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4200 || admin_ended_all_grace_periods)

/obj/map_metadata/caloocan/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4200 || admin_ended_all_grace_periods)


/obj/map_metadata/caloocan/roundend_condition_def2name(define)
	..()
	switch (define)
		if (FILIPINO)
			return "White"
		if (AMERICAN)
			return "Soviet"
/obj/map_metadata/caloocan/roundend_condition_def2army(define)
	..()
	switch (define)
		if (FILIPINO)
			return "Whites"
		if (AMERICAN)
			return "Soviets"

/obj/map_metadata/caloocan/army2name(army)
	..()
	switch (army)
		if ("Americans")
			return "American"
		if ("Filipinos")
			return "Filipino"


/obj/map_metadata/caloocan/cross_message(faction)
	if (faction == AMERICAN)
		return ""
	else if (faction == FILIPINO)
		return "<font size = 4>The American Army may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/caloocan/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return ""
	else if (faction == FILIPINO)
		return "<font size = 4>The American Army may no longer cross the invisible wall!</font>"
	else
		return ""


var/no_loop_cal = FALSE

/obj/map_metadata/caloocan/update_win_condition()
	if (!win_condition_specialcheck())
		return FALSE
	if (world.time >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Philippine Republic Army</b> has sucessfuly defended the church! The americans halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_cal == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>American Army</b> has captured the church! The battle for Caloocan is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_cal = TRUE
		return FALSE
	// RUSSIAN major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>American Army</b> has captured most of the church! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// RUSSIAN minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>American Army</b> has captured most of the church! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>American Army</b> has captured most of the church! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>American Army</b> has captured most of the church! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Filipinos</b> have recaptured the church!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE
