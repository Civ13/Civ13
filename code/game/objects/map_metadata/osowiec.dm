/obj/map_metadata/osowiec
	ID = MAP_OSOWIEC
	title = "Osowiec"
	lobby_icon = "icons/lobby/ww1.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 0
	no_hardcore = FALSE

	faction_organization = list(
		RUSSIAN,
		GERMAN)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/farm,
		list(GERMAN) = /area/caribbean/japanese/land/inside/command,
		)
	age = "1915"
	faction_distribution_coeffs = list(RUSSIAN = 0.3, GERMAN = 0.7)
	battle_name = "Siege of The Osowiec fort"
	mission_start_message = "<font size=3>The <b>German army</b> and the <b>Russian Army</b> are battling for the control of the osowiec fort! The Russians will win if they hold the fort for <b>30 minutes</b> The germans will win if the manage to hold the fort for <b>6 minutes</b>.<br>The battle will start in <b>5 minutes</b>.</font>"
	faction1 = RUSSIAN
	faction2 = GERMAN
	ordinal_age = 5
	songs = list(
		"Argonnerwaldlied:1" = "sound/music/argonnerwaldlied.ogg")
	gamemode = "Siege"
/obj/map_metadata/osowiec/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 36000 || admin_ended_all_grace_periods)

/obj/map_metadata/osowiec/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/osowiec/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/german))
		if (J.is_ww1)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/russian))
		if (J.is_russojapwar)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/osowiec/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/osowiec/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/osowiec/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Russians"
		if (GERMAN)
			return "Germans"

/obj/map_metadata/osowiec/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Russian Army"
		if (GERMAN)
			return "German Army"
/obj/map_metadata/osowiec/army2name(army)
	..()
	switch (army)
		if ("Russians")
			return "Russian"
		if ("Germans")
			return "German"

/obj/map_metadata/osowiec/cross_message(faction)
	if (faction == GERMAN)
		return "<font size = 3>The Germans may now cross the invisible wall!</font>"
	else if (faction == RUSSIAN)
		return "<font size = 3>The Germans may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/osowiec/reverse_cross_message(faction)
	if (faction == GERMAN)
		return "<span class = 'userdanger'>The Germans may no longer cross the invisible wall!</span>"
	else if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Germans may no longer cross the invisible wall!</span>"
	else
		return ""

/obj/map_metadata/osowiec/update_win_condition()

	if (world.time >= 18000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Russian Army</b> has sucessfuly defended Fort Osowiec! The Germans have halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_r == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Germans</b> have captured the Fort! The battle for Fort Osowiec is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_r = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the Fort! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the Fort! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Fort! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Fort! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])

	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The [current_winner] has lost control of the Fort!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/osowiec/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction2)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction1)
				return TRUE
		else
			return !faction2_can_cross_blocks()
	return FALSE