#define NO_WINNER "The fighting is still going on."
/obj/map_metadata/karak
	ID = MAP_KARAK
	title = "Karak (80x80x1)"
	lobby_icon_state = "medieval"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		ARAB,
		FRENCH)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(ARAB) = /area/caribbean/colonies,
		list(FRENCH) = /area/caribbean/crusader,
		)
	age = "1013"
	ordinal_age = 3
	faction_distribution_coeffs = list(ARAB = 0.5, FRENCH = 0.5)
	battle_name = "karak of Karak"
	mission_start_message = "<font size=4>The <b>Caliphate</b> troops are besieging the <b>Crusader</b> fortress of Karak! The Crusaders will win if they manage to hold the fortress for 35 minutes. <br> The siege will start in <b>6 minutes</b>.</font>"
	faction1 = ARAB
	faction2 = FRENCH
	ambience = list('sound/ambience/desert.ogg')
	songs = list(
		"Crusaders:1" = 'sound/music/crusaders.ogg')
	gamemode = "Siege"
/obj/map_metadata/karak/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/karak/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

obj/map_metadata/karak/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/arab))
		if (J.is_coldwar || J.is_specops)
			. = FALSE
		else
			. = TRUE
	if (istype(J, /datum/job/french))
		if (J.is_crusader == TRUE)
			. = TRUE
		else
			. = FALSE


/obj/map_metadata/karak/roundend_condition_def2name(define)
	..()
	switch (define)
		if (FRENCH)
			return "Crusader"

/obj/map_metadata/karak/roundend_condition_def2army(define)
	..()
	switch (define)
		if (FRENCH)
			return "Crusaders"

/obj/map_metadata/karak/army2name(army)
	..()
	switch (army)
		if ("Crusaders")
			return "Crusader"


/obj/map_metadata/karak/cross_message(faction)
	if (faction == ARAB)
		return "<font size = 4>The Arabs may now cross the invisible wall!</font>"
	else if (faction == FRENCH)
		return "<font size = 4>The Crusaders may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/karak/reverse_cross_message(faction)
	if (faction == ARAB)
		return "<span class = 'userdanger'>The Arabs may no longer cross the invisible wall!</span>"
	else if (faction == FRENCH)
		return "<span class = 'userdanger'>The Crusaders may no longer cross the invisible wall!</span>"
	else
		return ""



var/no_loop_kar = FALSE

/obj/map_metadata/karak/update_win_condition()
	if (!win_condition_specialcheck())
		return FALSE
	if (world.time >= 21000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The Crusaders have managed to defend the fortress!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_kar == FALSE)
		ticker.finished = TRUE
		var/message = "The Arabic Caliphate has captured the fortress! The remaining Crusaders have surrendered!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_kar = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Arabic Caliphate have the control over most of the Fortress! They will win in {time} minutes."
				next_win = world.time +  short_win_time(FRENCH)
				announce_current_win_condition()
				current_winner = "Arabic Caliphate"
				current_loser = "Crusaders"
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Arabic Caliphate have the control over most of the Fortress! They will win in {time} minutes."
				next_win = world.time +  short_win_time(FRENCH)
				announce_current_win_condition()
				current_winner = "Arabic Caliphate"
				current_loser = "Crusaders"
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition =  "The Arabic Caliphate have the control over most of the Fortress! They will win in {time} minutes."
				next_win = world.time +  short_win_time(ARAB)
				announce_current_win_condition()
				current_winner = "Arabic Caliphate"
				current_loser = "Crusaders"
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Arabic Caliphate have the control over most of the Fortress! They will win in {time} minutes."
				next_win = world.time + short_win_time(ARAB)
				announce_current_win_condition()
				current_winner = "Arabic Caliphate"
				current_loser = "Crusaders"
	else
		if (current_win_condition != NO_WINNER && current_winner && current_loser)
			world << "<font size = 3>The Crusaders have recaptured the fortress!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = NO_WINNER
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

	#undef NO_WINNER