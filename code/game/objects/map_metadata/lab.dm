/obj/map_metadata/lab
	ID = MAP_LAB
	title = "Lab"
	lobby_icon = "icons/lobby/ww2.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/temperate, /area/caribbean/no_mans_land/invisible_wall/four)
	respawn_delay = 1200
	no_winner ="No one has escaped yet."
	no_hardcore = FALSE
	faction_organization = list(
		LABPR,
		PRISONERS)

	roundend_condition_sides = list(
		list(PRISONERS) = /area/caribbean/no_mans_land/capturable/three,
		list(LABPR) = /area/caribbean,
		)
	age = "2030"
	ordinal_age = 8
	faction_distribution_coeffs = list(LABPR = 0.3, PRISONERS = 0.7)
	battle_name = "Lab breach"
	mission_start_message = "<font size=4>All factions have <b>8 minutes</b> to prepare before all hell breaks lose!<br>The Lab personnel and PMCS will win if they prevent escape for <b>40 minutes</b>. The Prisoners will win if they manage to reach and hold past the Bridge for 5 minutes.</font>"
	faction1 = LABPR
	faction2 = PRISONERS
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	gamemode = "Lab breach"


/obj/map_metadata/lab/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 60000 || admin_ended_all_grace_periods)

/obj/map_metadata/lab/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)

/obj/map_metadata/lab/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/lab/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/lab/roundend_condition_def2name(define)
	..()
	switch (define)
		if (LABPR)
			return "Labpr"
		if (PRISONERS)
			return "prisoners"
/obj/map_metadata/lab/roundend_condition_def2army(define)
	..()
	switch (define)
		if (LABPR)
			return "Labpr"
		if (PRISONERS)
			return "prisoners"

/obj/map_metadata/lab/army2name(army)
	..()
	switch (army)
		if ("LABPR")
			return "labpr"
		if ("PRISONERS")
			return "prisoners"


/obj/map_metadata/lab/cross_message(faction)
	if (faction == PRISONERS)
		return "<font size = 4>The Prisoners may now cross the invisible wall!</font>"
	else if (faction == LABPR)
		return ""
	else
		return ""

/obj/map_metadata/lab/reverse_cross_message(faction)
	if (faction == PRISONERS)
		return "<span class = 'userdanger'>The Prisoners may no longer cross the invisible wall!</span>"
	else if (faction == LABPR)
		return ""
	else
		return ""


/obj/map_metadata/lab/update_win_condition()

	if (world.time >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>PMCS</b> have sucessfuly defended the lab bridge! Order has been restored!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_r == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Prisoners</b> have captured the lab Bridge! The battle for the lab is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_r = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>prisoners</b> have reached past the bridge! They will win in {time} minutes."
				next_win = world.time + short_win_time(PRISONERS)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>prisoners</b> have reached past the bridge! They will win in {time} minutes."
				next_win = world.time + short_win_time(PRISONERS)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>prisoners</b> have reached past the bridge! They will win in {time} minutes."
				next_win = world.time + short_win_time(PRISONERS)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>prisoners</b> have reached past the bridge! They will win in {time} minutes."
				next_win = world.time + short_win_time(PRISONERS)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Lab personnel</b> have recaptured the Bridge!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE
