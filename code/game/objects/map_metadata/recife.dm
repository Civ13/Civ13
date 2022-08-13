
/obj/map_metadata/recife
	ID = MAP_RECIFE
	title = "Recife"
	lobby_icon = "icons/lobby/imperial.png"
	no_winner ="The fighting for the town is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 900
	no_hardcore = TRUE
	faction_organization = list(
		PORTUGUESE,
		DUTCH)

	roundend_condition_sides = list(
		list(PORTUGUESE) = /area/caribbean/colonies/portuguese,
		list(DUTCH) = /area/caribbean/colonies/spanish, //on purpose, to prevent capture
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(PORTUGUESE = 0.4, DUTCH = 0.6)
	battle_name = "Battle of Recife"
	mission_start_message = "<font size=4>Dutch forces are sieging the Portuguese town of Recife! They have <b>40 minutes</b> to capture it. Dutch may attack after <b>10 minutes</b>.</font><br><font size=2>The key points that need to be captured are: <b>Governors Office, Army Barracks (Fortress)</b></font>"
	faction1 = PORTUGUESE
	faction2 = DUTCH
	ambience = list('sound/ambience/jungle1.ogg')
	gamemode = "Siege"
	grace_wall_timer = 6000
obj/map_metadata/recife/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_army == TRUE)
		. = TRUE
	else
		. = FALSE

var/no_loop = FALSE

/obj/map_metadata/recife/update_win_condition()

	if (processes.ticker.playtime_elapsed >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The Portuguese colonial troops have managed to defend Recife!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop == FALSE)
		ticker.finished = TRUE
		var/message = "The Dutch have captured Recife! The remaining Portuguese troops have surrendered!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Dutch troops have the control over most of the Town! They will win in 2 minutes."
				next_win = world.time +  short_win_time(DUTCH)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Dutch troops have the control over most of the Town! They will win in 2 minutes."
				next_win = world.time +  short_win_time(DUTCH)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition =  "The Dutch troops have the control over most of the Town! They will win in 2 minutes."
				next_win = world.time +  short_win_time(PORTUGUESE)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Dutch troops have the control over most of the Town! They will win in 2 minutes."
				next_win = world.time + short_win_time(PORTUGUESE)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The Portuguese troops have recaptured the town!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

