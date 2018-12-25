#define NO_WINNER "The fighting is still going on."
/obj/map_metadata/hill203
	ID = MAP_HILL203
	title = "Hill_203 (50x50x1)"
	lobby_icon_state = "hill_203"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		JAPANESE,
		RUSSIAN)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(JAPANESE) = /area/caribbean/japanese,
		list(RUSSIAN) = /area/caribbean/russian/land/inside,
		)
	age = "1904"
	faction_distribution_coeffs = list(JAPANESE = 0.6, RUSSIAN = 0.4)
	battle_name = "Seige of Port Arthur: Hill 203"
	mission_start_message = "<font size=4>The <b>Japanese</b> troops are fighting for the <b>Russian</b> controlled Hill 203! The Russians will win if they manage to hold the hill for 42 minutes. <br> The battle will start will start in <b>7 minutes</b>.</font>"
	faction1 = JAPANESE
	faction2 = RUSSIAN
	songs = list(
		"Russo-japanese war song:1" = 'sound/music/russo-jap_war_song.ogg',
		"Yuki no Shingun:1" = 'sound/music/yuki_no_shingun.ogg')

/obj/map_metadata/hill203/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 20000 || admin_ended_all_grace_periods)

/obj/map_metadata/hill203/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4200 || admin_ended_all_grace_periods)

obj/map_metadata/hill203/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/japanese))
		. = TRUE
	if (istype(J, /datum/job/russian))
		. = TRUE


/obj/map_metadata/hill203/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Russian"

/obj/map_metadata/hill203/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Russians"

/obj/map_metadata/hill203/cross_message(faction)
	if (faction == JAPANESE)
		return "<font size = 4>The Imperial Japanese Army may now cross the invisible wall!</font>"
	else if (faction == RUSSIAN)
		return "<font size = 4>The Russians may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/hill203/reverse_cross_message(faction)
	if (faction == JAPANESE)
		return "<span class = 'userdanger'>The Imperial Japanese Army may no longer cross the invisible wall!</span>"
	else if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Russians may no longer cross the invisible wall!</span>"
	else
		return ""



var/no_loop_hill203 = FALSE

/obj/map_metadata/hill203/update_win_condition()
	if (!win_condition_specialcheck())
		return FALSE
	if (world.time >= 42000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The RUssians have managed to defend hill 203!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_kar == FALSE)
		ticker.finished = TRUE
		var/message = "The Imperial Japanese Army has captured the hill! The remaining Russian troops have surrendered!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_kar = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Imperial Japanese Army has the control over most of the hill! They will win in 2 minutes."
				next_win = world.time +  short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Imperial Japanese Army has the control over most of the hill! They will win in 2 minutes."
				next_win = world.time +  short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition =  "The Imperial Japanese Army has the control over most of the hill! They will win in 2 minutes."
				next_win = world.time +  short_win_time(JAPANESE)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Imperial Japanese Army has the control over most of the hill! They will win in 2 minutes."
				next_win = world.time + short_win_time(JAPANESE)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != NO_WINNER && current_winner && current_loser)
			world << "<font size = 3>The Russians have recaptured the hill!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = NO_WINNER
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

	#undef NO_WINNER