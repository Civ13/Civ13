/obj/map_metadata/hill_3234
	ID = MAP_HILL_3234
	title = "Battle for Hill 3234"
	no_winner = "Hill 3234 is still under the Soviet forces control."
	lobby_icon = "icons/lobby/sovafghan.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/one, /area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 0
	victory_time = 24000
	no_hardcore = TRUE

	faction_organization = list(
		RUSSIAN,
		ARAB)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/no_mans_land/capturable/one,
		list(ARAB) = /area/caribbean/british
		)
	age = "1988"
	ordinal_age = 7
	faction_distribution_coeffs = list(RUSSIAN = 0.3, ARAB = 0.7)
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the battle begins!<br>The <font color = 'red'>Soviets</font> will win if they hold out the hill for <b>40 minutes</b>.<br>The <b><font color = 'black'>Mujahideen</font></b> will win if they manage to capture the radio station on the top of the hill!</font>"
	faction1 = RUSSIAN
	faction2 = ARAB
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Kino - Gruppa Krovi (Blood Group):1" = "sound/music/gruppakrovi.ogg",)
	gamemode = "Siege"
	artillery_count = 3
	grace_wall_timer = 3000

/obj/map_metadata/hill_3234/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_afghan)
		. = TRUE
		if (J.title == "Soviet Army Tanker")
			. = FALSE
		if (J.title == "Soviet Army Tank Commander")
			. = FALSE
		if (J.title == "Soviet Army Captain")
			. = FALSE
		if (J.title == "Soviet Army Lieutenant")
			J.max_positions = 1
			J.total_positions = 1
			J.is_commander = TRUE
		if (J.title == "Soviet Army Sergeant")
			J.max_positions = 5
			J.total_positions = 5
		if (J.title == "Soviet Army Field Medic")
			J.max_positions = 4
			J.total_positions = 4
		if (J.title == "Soviet Army Radio Operator")
			J.max_positions = 4
			J.total_positions = 4
		if (J.title == "Soviet Army Private")
			J.max_positions = 60
			J.total_positions = 60
		if (J.title == "Spetznaz GRU")
			J.max_positions = 2
			J.total_positions = 2
		if (J.title == "Mujahideen Leader")
			J.max_positions = 10
			J.total_positions = 10
	else
		. = FALSE

/obj/map_metadata/hill_3234/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/hill_3234/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/hill_3234/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Soviet Army"
		if (ARAB)
			return "Mujahideen"
/obj/map_metadata/hill_3234/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Soviets"
		if (ARAB)
			return "Mujahideen"

/obj/map_metadata/hill_3234/army2name(army)
	..()
	switch (army)
		if ("Soviet Army")
			return "Soviet Army"
		if ("ARAB")
			return "Mujahideen"

/obj/map_metadata/hill_3234/cross_message(faction)
	if (faction == ARAB)
		return "<font size = 4>The <font color = 'black'>Mujahideen</font> may now cross the invisible wall!</font>"
	else if (faction == RUSSIAN)
		return ""
	else
		return ""

/obj/map_metadata/hill_3234/reverse_cross_message(faction)
	if (faction == ARAB)
		return "<span class = 'userdanger'>The <font color = 'black'>Mujahideen</font> may no longer cross the invisible wall!</span>"
	else if (faction == RUSSIAN)
		return ""
	else
		return ""

/obj/map_metadata/hill_3234/update_win_condition()

	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <font color = 'red'>Soviets</font> have sucessfuly defended Hill 3234! The Mujahideen halted their attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_o == FALSE)
		ticker.finished = TRUE
		var/message = "The <font color = 'black'>Mujahideen</font> have captured Hill 3234! The Soviets have been wiped out!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_o = TRUE
		return FALSE
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The<font color = 'black'>Mujahideen</font> are capturing Hill 3234! They will win in {time} minutes."
				next_win = world.time + short_win_time(ARAB)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The<font color = 'black'>Mujahideen</font> are capturing Hill 3234! They will win in {time} minutes."
				next_win = world.time + short_win_time(ARAB)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The<font color = 'black'>Mujahideen</font> are capturing Hill 3234! They will win in {time} minutes."
				next_win = world.time + short_win_time(ARAB)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The<font color = 'black'> Mujahideen</font> are capturing Hill 3234! They will win in {time} minutes."
				next_win = world.time + short_win_time(ARAB)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3><font color = 'red'>The Soviets</font> have recaptured Hill 3234!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/hill_3234/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction1)
				return TRUE
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/three))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE
