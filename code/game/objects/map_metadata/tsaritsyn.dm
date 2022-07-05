
/obj/map_metadata/tsaritsyn
	ID = MAP_TSARITSYN
	title = "Tsaritsyn"
	lobby_icon = "icons/lobby/rcw.png"
	no_winner ="The church is under Soviet control."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 600
	no_hardcore = TRUE
	faction_organization = list(
		RUSSIAN,
		CIVILIAN)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/russian/land/inside/command,
		)
	age = "1919"
	ordinal_age = 5
	faction_distribution_coeffs = list(RUSSIAN = 0.5, CIVILIAN = 0.5)
	battle_name = "battle for the church"
	mission_start_message = "<font size=4>All factions have <b>7 minutes</b> to prepare before the ceasefire ends!<br>The <b>Soviets</b> will win if they hold out for <b>40 minutes</b>. The <b>White Army</b> will win if they manage to capture the centre of the church.</font>"
	faction1 = CIVILIAN
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	ordinal_age = 5
	grace_wall_timer = 4200
	songs = list(
		"Korobushka:1" = "sound/music/korobushka.ogg")
	gamemode = "Siege"

obj/map_metadata/tsaritsyn/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/russian))
		if (J.is_rcw == TRUE)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/civilian))
		if (J.is_rcw == TRUE)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/tsaritsyn/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "White"
		if (CIVILIAN)
			return "Soviet"
/obj/map_metadata/tsaritsyn/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Whites"
		if (CIVILIAN)
			return "Soviets"

/obj/map_metadata/tsaritsyn/army2name(army)
	..()
	switch (army)
		if ("Whites")
			return "White"
		if ("Soviets")
			return "Soviet"


/obj/map_metadata/tsaritsyn/cross_message(faction)
	if (faction == CIVILIAN)
		return ""
	else if (faction == RUSSIAN)
		return "<font size = 4>The White Army may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/tsaritsyn/reverse_cross_message(faction)
	if (faction == CIVILIAN)
		return ""
	else if (faction == RUSSIAN)
		return "<font size = 4>The White Army may no longer cross the invisible wall!</font>"
	else
		return ""


var/no_loop_t = FALSE

/obj/map_metadata/tsaritsyn/update_win_condition()

	if (world.time >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Red Army</b> has sucessfuly defended the church! The whites halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_t == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>White Army</b> has captured the church! The battle for is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_t = TRUE
		return FALSE
	// RUSSIAN major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>White Army</b> has captured most of the church! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// RUSSIAN minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>White Army</b> has captured most of the church! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>White Army</b> has captured most of the church! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>White Army</b> has captured most of the church! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Soviets</b> have recaptured the church!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/tsaritsyn/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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