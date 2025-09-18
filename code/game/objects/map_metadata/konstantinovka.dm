/obj/map_metadata/konstantinovka
	ID = MAP_KONSTANTINOVKA
	title = "Konstantinovka"
	lobby_icon = 'icons/lobby/konstantinovka.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/desert)
	respawn_delay = 1200
	no_winner = "The operation is still underway."

	faction_organization = list(
		RUSSIAN,
		AMERICAN)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/arab,
		list(AMERICAN) = /area/caribbean/british
		)
	age = "2023"
	ordinal_age = 8

	faction_distribution_coeffs = list(RUSSIAN = 0.5, AMERICAN = 0.5)
	battle_name = "battle for the town"
	mission_start_message = "<font size=4>The <b>Defensive side</b> is holding the town. <b>Attacking side</b> troops must capture the Konstantinovka (SE corner) within <b>40 minutes</b>!</font>"
	faction1 = RUSSIAN
	faction2 = AMERICAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"I am soldier - by 5'Nizza - (Cover by Carla's Dreams):1" = 'sound/music/i_am_soldier_cover_by_carlas_dreams.ogg',)
	artillery_count = 3
	valid_artillery = list("Explosive")

/obj/map_metadata/konstantinovka/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_modernday == TRUE && (istype(J, /datum/job/american/usmc_lieutenant/east_europe) || istype(J, /datum/job/russian/modern_rifleman)))
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/konstantinovka/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 30000 || admin_ended_all_grace_periods)

/obj/map_metadata/konstantinovka/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


/obj/map_metadata/konstantinovka/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Defensive side"
		if (AMERICAN)
			return "Attacking side"
/obj/map_metadata/konstantinovka/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Defensive side"
		if (AMERICAN)
			return "Attacking side"

/obj/map_metadata/konstantinovka/army2name(army)
	..()
	switch (army)
		if ("Defensive side")
			return "Defensive side"
		if ("Attacking side")
			return "Attacking side"


/obj/map_metadata/konstantinovka/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The Attacking side may now cross the invisible wall!</font>"
	else if (faction == RUSSIAN)
		return ""
	else
		return ""

/obj/map_metadata/konstantinovka/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The Attacking side may no longer cross the invisible wall!</span>"
	else if (faction == RUSSIAN)
		return ""
	else
		return ""

var/no_loop_russian = FALSE

/obj/map_metadata/konstantinovka/update_win_condition()

	if (world.time >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The Defensive side has managed to defend Konstantinovka!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_russian == FALSE)
		ticker.finished = TRUE
		var/message = "The Attacking side has captured Konstantinovka! Russia retreats!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_russian = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Attacking side controls the Konstantinovka! They will win in {time} minutes."
				next_win = world.time +  short_win_time(ARAB)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Attacking side controls the Konstantinovka! They will win in {time} minutes."
				next_win = world.time +  short_win_time(ARAB)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Attacking side controls the Konstantinovka! They will win in {time} minutes."
				next_win = world.time +  short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Attacking side controls the Konstantinovka! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The Defensive side has recaptured Konstantinovka!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE