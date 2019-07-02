#define NO_WINNER "The operation is still underway."
/obj/map_metadata/arab_town
	ID = MAP_ARAB_TOWN
	title = "Arab Town (100x100x1)"
	lobby_icon_state = "modern"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 1200
	squad_spawn_locations = FALSE
	faction_organization = list(
		AMERICAN,
		ARAB)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/british,
		list(ARAB) = /area/caribbean/arab
		)
	age = "2006"
	ordinal_age = 8
	faction_distribution_coeffs = list(AMERICAN = 0.5, ARAB = 0.5)
	battle_name = "battle for the town"
	mission_start_message = "<font size=4>The <b>Hezbollah</b> is holding the town. <b>IDF</b> troops must capture the Hezbollah HQ (SW corner) within <b>40 minutes</b>!</font>"
	faction1 = AMERICAN
	faction2 = ARAB
	valid_weather_types = list(WEATHER_NONE, WEATHER_SANDSTORM)
	songs = list(
		"Qom Nasheed:1" = 'sound/music/qom_nasheed.ogg',)
	artillery_count = 3
	valid_artillery = list("Explosive")
obj/map_metadata/arab_town/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_modernday == TRUE && (istype(J, /datum/job/american/idf) || istype(J, /datum/job/arab/hezbollah)))
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


var/no_loop_arab = FALSE

/obj/map_metadata/arab_town/update_win_condition()
	if (!win_condition_specialcheck())
		return FALSE
	if (world.time >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The Hezbollah has managed to defend their HQ!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_arab == FALSE)
		ticker.finished = TRUE
		var/message = "The IDF has captured Hezbollah's HQ! Hezbollah retreats!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_arab = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The IDF controls the Hezbollah HQ! They will win in {time} minutes."
				next_win = world.time +  short_win_time(ARAB)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The IDF controls the Hezbollah HQ! They will win in {time} minutes."
				next_win = world.time +  short_win_time(ARAB)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The IDF controls the Hezbollah HQ! They will win in {time} minutes."
				next_win = world.time +  short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The IDF controls the Hezbollah HQ! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != NO_WINNER && current_winner && current_loser)
			world << "<font size = 3>The Hezbollah has recaptured their HQ!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = NO_WINNER
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

	#undef NO_WINNER