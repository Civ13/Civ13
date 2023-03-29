/obj/map_metadata/reichflakturm
	ID = MAP_REICHFLAKTURM
	title = "Reichflakturm"
	lobby_icon = "icons/lobby/ww2.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 1200
	no_hardcore = TRUE
	victory_time = 24000

	faction_organization = list(
		GERMAN,
		AMERICAN)

	roundend_condition_sides = list(
		list(GERMAN) = /area/caribbean/german/inside/roof/objective,
		list(AMERICAN) = /area/caribbean/british,
		)
	age = "1944"
	ordinal_age = 6
	faction_distribution_coeffs = list(GERMAN = 0.35, AMERICAN = 0.65)
	battle_name = "Battle of the Reichflakturm"
	mission_start_message = "<font size=4>All factions have <b>4 minutes</b> to prepare before the battle begins!<br>The Germans will win if they hold out for <b>40 minutes</b>. The Americans will win if they manage to capture the anti-air guns at the top of the tower!</font>"
	faction1 = GERMAN
	faction2 = AMERICAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Over There!:1" = "sound/music/overthere.ogg",)
	gamemode = "Siege"
/obj/map_metadata/reichflakturm/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_tanker == TRUE || J.is_occupation == TRUE || J.is_reichstag == TRUE || J.is_ss_panzer == TRUE || J.is_navy == TRUE || (istype(J, /datum/job/american/soldier_ww2_filipino)))
		. = FALSE
	else if (J.is_ww2 == TRUE && J.is_reichstag == FALSE)
		. = TRUE
	else if (istype(J, /datum/job/german/german_antitank) || istype(J, /datum/job/german/german_antitankassitant))
		. = FALSE
	else
		. = FALSE

/obj/map_metadata/reichflakturm/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 2400 || admin_ended_all_grace_periods)

/obj/map_metadata/reichflakturm/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 26000 || admin_ended_all_grace_periods)

/obj/map_metadata/reichflakturm/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/reichflakturm/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/reichflakturm/roundend_condition_def2name(define)
	..()
	switch (define)
		if (GERMAN)
			return "German"
		if (AMERICAN)
			return "American"
/obj/map_metadata/reichflakturm/roundend_condition_def2army(define)
	..()
	switch (define)
		if (GERMAN)
			return "Germans"
		if (AMERICAN)
			return "Americans"

/obj/map_metadata/reichflakturm/army2name(army)
	..()
	switch (army)
		if ("Germans")
			return "German"
		if ("Americans")
			return "American"


/obj/map_metadata/reichflakturm/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The Americans may now cross the invisible wall!</font>"
	else if (faction == GERMAN)
		return ""
	else
		return ""

/obj/map_metadata/reichflakturm/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The Americans may no longer cross the invisible wall!</span>"
	else if (faction == GERMAN)
		return ""
	else
		return ""


/obj/map_metadata/reichflakturm/update_win_condition()

	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Wehrmacht</b> has sucessfuly defended the Reichflakturm! The Americans halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_o == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Americans</b> have captured the anti-air guns! The Battle for the Reichflakturmis over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_o = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Americans</b> have captured the anti-air guns! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Americans</b> have captured the anti-air guns! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Americans</b> have captured the anti-air guns! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Americans</b> have captured the anti-air guns! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Germans</b> have recaptured the anti-air guns!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE
