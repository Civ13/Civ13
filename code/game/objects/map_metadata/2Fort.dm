/obj/map_metadata/camp
	ID = MAP_CAMP
	title = "Camp"
	lobby_icon = "icons/lobby/medieval.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0
	has_hunger = TRUE
	no_winner = "No faction controls the Castle."

	faction_organization = list(
		BRITISH,
		FRENCH)

	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/island,
		list(FRENCH) = /area/caribbean/island
		)
	age = "Unknown"
	ordinal_age = 2
	faction_distribution_coeffs = list(BRITISH = 0.5, FRENCH = 0.5)
	songs = list(
		"Crusaders:1" = "sound/music/crusaders.ogg")
	battle_name = "battle of Normandy"
	mission_start_message = "<font size=4>The <b>French</b> and <b>English</b> armies are facing each other in Northern France! There is a <b>Castle</b> in the middle of the map, that must be captured and held for 8 minutes! The battle will start in <b>6 minutes</b>.</font>"
	faction1 = BRITISH
	faction2 = FRENCH
	ambience = list('sound/ambience/jungle1.ogg')
	gamemode = "King of the Hill"
	grace_wall_timer = 3600
obj/map_metadata/camp/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_medieval == TRUE)
		. = TRUE
	else
		. = FALSE
	if (J.is_crusader == TRUE)
		. = FALSE

/obj/map_metadata/camp/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 4800 // 8 minutes

/obj/map_metadata/camp/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 4800 // 8 minutes

/obj/map_metadata/camp/roundend_condition_def2name(define)
	..()
	switch (define)
		if (BRITISH)
			return "English"

/obj/map_metadata/camp/roundend_condition_def2army(define)
	..()
	switch (define)
		if (BRITISH)
			return "Kingdom of England"
		if (FRENCH)
			return "Kingdom of France"

/obj/map_metadata/camp/army2name(army)
	..()
	switch (army)
		if ("Kingdom of England")
			return "English"
		if ("Kingdom of France")
			return "French"


/obj/map_metadata/camp/cross_message(faction)
	if (faction == BRITISH)
		return "<font size = 4>The English may now cross the invisible wall!</font>"
	else if (faction == FRENCH)
		return "<font size = 4>The French may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/camp/reverse_cross_message(faction)
	if (faction == ENGLISH)
		return "<span class = 'userdanger'>The English may no longer cross the invisible wall!</span>"
	else if (faction == FRENCH)
		return "<span class = 'userdanger'>The French may no longer cross the invisible wall!</span>"
	else
		return ""

/obj/map_metadata/camp/update_win_condition()

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
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the Castle! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the Castle! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Castle! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Castle! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])

	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The [current_winner] has lost control of the Castle!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE
