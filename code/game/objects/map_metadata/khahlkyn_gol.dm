#define NO_WINNER "The reichstag is under German control."
/obj/map_metadata/khalkhyn
	ID = MAP_KHALKHYN_GOL
	title = "Khalkhyn Gol (150x200x1)"
	lobby_icon_state = "ww2"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 1200
	squad_spawn_locations = FALSE
	faction_organization = list(
		JAPANESE,
		RUSSIAN)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/russian/land/inside/command,
		list(JAPANESE) = /area/caribbean/japanese/land/inside/command,
		)
	age = "1945"
	ordinal_age = 6
	faction_distribution_coeffs = list(JAPANESE = 0.6, RUSSIAN = 0.4)
	battle_name = "battle of Khalkhyn Gol"
	mission_start_message = "<font size=4>All factions have <b>10 minutes</b> to prepare before the ceasefire ends!<br>The Japanese will win if they capture the <b>Soviet command!</b>. The Soviets will win if they manage to capture the japanese command!.</font>"
	faction1 = JAPANESE
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_RAIN)
	songs = list(
		"Doki no Sakura:2" = 'sound/music/doki_no_sakura.ogg')

/obj/map_metadata/khalkhyn/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_ww2 == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/khalkhyn/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 30000 || admin_ended_all_grace_periods)

/obj/map_metadata/khalkhyn/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 6000 || admin_ended_all_grace_periods)


/obj/map_metadata/khalkhyn/roundend_condition_def2name(define)
	..()
	switch (define)
		if (JAPANESE)
			return "Japanese"
		if (RUSSIAN)
			return "Soviet"
/obj/map_metadata/khalkhyn/roundend_condition_def2army(define)
	..()
	switch (define)
		if (JAPANESE)
			return "Japanese"
		if (RUSSIAN)
			return "Soviets"

/obj/map_metadata/khalkhyn/army2name(army)
	..()
	switch (army)
		if ("Japanese")
			return "Japanese"
		if ("Soviets")
			return "Soviet"


/obj/map_metadata/khalkhyn/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The Soviets may now cross the invisible wall!</font>"
	else if (faction == JAPANESE)
		return "<font size = 4>The Japanese may now cross the invisible wall!</font>"

/obj/map_metadata/khalkhyn/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Soviets may no longer cross the invisible wall!</span>"
	else if (faction == JAPANESE)
		return "<span class = 'userdanger'>The Japanese may no longer cross the invisible wall!</span>"

var/no_loop_kal = FALSE

/obj/map_metadata/khalkhyn/update_win_condition()
	if (!win_condition_specialcheck())
		return FALSE
	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = ""
		if (!map.civilizations)
			message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		else
			message = "The round has ended!"
		if (current_winner && current_loser)
			message = "The battle is over! The [current_winner] was victorious over the [current_loser][battle_name ? " in the [battle_name]" : ""]!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		win_condition_spam_check = TRUE
		return FALSE

	// 1st major
	if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[1], roundend_condition_sides[3], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[3], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the [roundend_condition_def2name(roundend_condition_sides[3][1])] base! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[3][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[3][1])
	// 1st minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[1], roundend_condition_sides[3], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[3], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the [roundend_condition_def2name(roundend_condition_sides[3][1])] base! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[3][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[3][1])
	// 2nd major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[2], roundend_condition_sides[3], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[3], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the [roundend_condition_def2name(roundend_condition_sides[3][1])] base! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[3][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[3][1])
	// 2nd minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[2], roundend_condition_sides[3], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[3], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the [roundend_condition_def2name(roundend_condition_sides[3][1])] base! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[3][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[3][1])
	// 3rd major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[3], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[1], roundend_condition_sides[3], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[3][1])] has captured the [roundend_condition_def2name(roundend_condition_sides[1][1])] base! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[3][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// 3rd minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[3], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[1], roundend_condition_sides[3], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[3][1])] has captured the [roundend_condition_def2name(roundend_condition_sides[1][1])] base! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[3][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// 3rd major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[3], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[2], roundend_condition_sides[3], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[3][1])] has captured the [roundend_condition_def2name(roundend_condition_sides[2][1])] base! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[3][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// 3rd minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[3], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[3]]), roundend_condition_sides[2], roundend_condition_sides[3], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[3][1])] has captured the [roundend_condition_def2name(roundend_condition_sides[2][1])] base! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[3][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	else
		if (current_win_condition != NO_WINNER && current_winner && current_loser)
			world << "<font size = 3>The [current_winner] has lost control of the [army2name(current_loser)] base!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = NO_WINNER
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

	#undef NO_WINNER