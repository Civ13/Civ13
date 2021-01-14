/obj/map_metadata/capitol_hill
	ID = MAP_CAPITOL_HILL
	title = "Capitol Hill"
	lobby_icon_state = "modern"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/desert)
	respawn_delay = 1200
	no_winner = "The operation is still underway."

	faction_organization = list(
		AMERICAN,
		CIVILIAN)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/arab
		)
	age = "2021"
	ordinal_age = 8
	faction_distribution_coeffs = list(AMERICAN = 0.3, CIVILIAN = 0.7)
	battle_name = "battle for the Capitol Hill"
	mission_start_message = "<font size=4>The <b>National Guard</b> is holding the U.S. Capitol! The <b>Militias</b> troops must capture both chambers (<b>Congress</b> and <b>Senate</b>) within <b>40 minutes</b>!<br>The round will start in <b>5</b> minutes.</font>"
	faction1 = AMERICAN
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Al-Qussam:1" = 'sound/music/alqassam.ogg',)
	artillery_count = 0
	valid_artillery = list()

/obj/map_metadata/capitol_hill/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_capitol == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/capitol_hill/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/capitol_hill/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


/obj/map_metadata/capitol_hill/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Militia"
		if (AMERICAN)
			return "National Guard"
/obj/map_metadata/capitol_hill/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Militias"
		if (AMERICAN)
			return "National Guards"

/obj/map_metadata/capitol_hill/army2name(army)
	..()
	switch (army)
		if ("Militias")
			return "Militia"
		if ("National Guards")
			return "National Guard"


/obj/map_metadata/capitol_hill/cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 4>The Militias may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/capitol_hill/reverse_cross_message(faction)
	if (faction == CIVILIAN)
		return "<span class = 'userdanger'>The Militias may no longer cross the invisible wall!</span>"
	else
		return ""


var/no_loop_capitol = FALSE

/obj/map_metadata/capitol_hill/update_win_condition()
	if (!win_condition_specialcheck())
		return FALSE
	if (world.time >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The National Guard has managed to defend the Capitol! The militias retreat!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_capitol == FALSE)
		ticker.finished = TRUE
		var/message = "The Militias have captured the Capitol!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_capitol = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Militias control the Capitol! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Militias control the Capitol! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Militias control the Capitol! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Militias control the Capitol! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The National Guard has recaptured the Capitol!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE
