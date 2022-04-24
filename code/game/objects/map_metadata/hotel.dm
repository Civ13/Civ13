/obj/map_metadata/hotel
	ID = MAP_HOTEL
	title = "hotel"
	lobby_icon_state = "ww2"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 0


	faction_organization = list(
		GERMAN,
		RUSSIAN)

	roundend_condition_sides = list(
		list(GERMAN) = /area/caribbean/no_mans_land/capturable,
		list(RUSSIAN) = /area/caribbean/no_mans_land/capturable,
		)
	age = "1943"
	faction_distribution_coeffs = list(GERMAN = 0.5, RUSSIAN = 0.5)
	battle_name = "Battle of the grand hotel"
	mission_start_message = "<font size=4>The <b>Wehrmacht</b> and the <b>Red Army</b> are battling for the control of the Grand Hotel!<br> The battle will start in <b>3 minutes</b>. Capture the <b>upstairs lounge</b> to control the Hotel!</font>"
	faction1 = GERMAN
	faction2 = RUSSIAN
	ordinal_age = 6
	songs = list(
		"Red Army Choir - Katyusha:1" = "sound/music/katyusha.ogg")
	gamemode = "King of the Hill"
/obj/map_metadata/hotel/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1800 || admin_ended_all_grace_periods)

/obj/map_metadata/hotel/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1800 || admin_ended_all_grace_periods)

/obj/map_metadata/hotel/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/german/tank_crew) || istype(J, /datum/job/russian/tank_crew))
		. = FALSE
	else if (J.is_ss_panzer == TRUE)
		. = FALSE
	else if (J.is_occupation == TRUE)
		. = FALSE
	else if (J.is_tanker == TRUE)
		. = FALSE
	else if (J.is_ww2 == TRUE && J.is_reichstag == FALSE)
		. = TRUE
	else if (J.is_reichstag == TRUE)
		. = FALSE
	else
		. = FALSE
/obj/map_metadata/hotel/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/hotel/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/hotel/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Russians"
		if (GERMAN)
			return "Germans"

/obj/map_metadata/hotel/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Russian Army"
		if (GERMAN)
			return "German Army"
/obj/map_metadata/hotel/army2name(army)
	..()
	switch (army)
		if ("Russians")
			return "Russian"
		if ("Germans")
			return "German"

/obj/map_metadata/hotel/cross_message(faction)
	if (faction == GERMAN)
		return "<font size = 4>The Germans may now cross the invisible wall!</font>"
	else if (faction == RUSSIAN)
		return "<font size = 4>The Russians may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/hotel/reverse_cross_message(faction)
	if (faction == GERMAN)
		return "<span class = 'userdanger'>The Germans may no longer cross the invisible wall!</span>"
	else if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Russians may no longer cross the invisible wall!</span>"
	else
		return ""

/obj/map_metadata/hotel/update_win_condition()

	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		if (current_winner && current_loser)
			message = "The battle is over! The [current_winner] was victorious over the [current_loser][battle_name ? " in the [battle_name]" : ""]!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		win_condition_spam_check = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the hotel! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the hotel! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the hotel! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the hotel! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])

	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The [current_winner] has lost control of the hotel!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/hotel/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE