/obj/map_metadata/magistral
	ID = MAP_MAGISTRAL
	title = "Operation Magistral"
	no_winner = "The compound is still under the Mujahideen's control."
	lobby_icon = "icons/lobby/magistral.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/one, /area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 0
	victory_time = 21000

	faction_organization = list(
		RUSSIAN,
		CIVILIAN,
		ARAB)

	roundend_condition_sides = list(
		list(RUSSIAN, CIVILIAN) = /area/caribbean/british,
		list(ARAB) = /area/caribbean/no_mans_land/capturable/one,
		)
	age = "1987"
	ordinal_age = 7
	faction_distribution_coeffs = list(RUSSIAN = 0.5, ARAB = 0.5)
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the battle begins!<br>The <font color = 'red'>Soviets</font> and the <font color = 'green'>DRA</font> will win if they capture the control room of the compound. <br>The <b><font color = 'black'>Mujahideen</font></b> will win if they manage to hold out for <b>35 minutes</b>!</font>"
	faction1 = RUSSIAN
	faction2 = ARAB
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Kaskad - Afgan:1" = "sound/music/afgan.ogg",)
	gamemode = "Siege"
	artillery_count = 3
	grace_wall_timer = 3000

/obj/map_metadata/magistral/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_afghan)
		if (J.is_soviet || J.is_dra || J.is_muj)
			. = TRUE
		if (J.title == "DRA Governor")
			. = FALSE
		if (J.title == "Mujahideen Leader")
			J.max_positions = 10
			J.total_positions = 10
	else
		. = FALSE

/obj/map_metadata/magistral/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/magistral/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/magistral/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Soviet Army"
		if (ARAB)
			return "Mujahideen"
/obj/map_metadata/magistral/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Soviets"
		if (ARAB)
			return "Mujahideen"
		if (CIVILIAN)
			return "DRA"

/obj/map_metadata/magistral/army2name(army)
	..()
	switch (army)
		if ("Soviet Army")
			return "Soviet Army"
		if ("ARAB")
			return "Mujahideen"
		if ("CIVILIAN")
			return "DRA"

/obj/map_metadata/magistral/cross_message(faction)
	if (faction == ARAB)
		return "<font size = 4>The <font color = 'red'>Soviet Army</font> and the <font color = 'green'>DRA</font> may now cross the invisible wall!</font>"
	else if (faction == RUSSIAN || faction == CIVILIAN)
		return "<font size = 4>The <font color = 'red'>Soviet Army</font> and the <font color = 'green'>DRA</font> may now cross the invisible wall!</font>"

/obj/map_metadata/magistral/reverse_cross_message(faction)
	if (faction == ARAB)
		return "<span class = 'userdanger'>The <font color = 'red'>Soviet Army</font> and the <font color = 'green'>DRA</font>  may no longer cross the invisible wall!</span>"
	else if (faction == RUSSIAN)
		return ""
	else
		return ""

/obj/map_metadata/magistral/update_win_condition()
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <font color = 'black'>Mujahideen</font> have successfully defended the kishlak's compound! The Soviets and DRA have failed their assault!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_o == FALSE)
		ticker.finished = TRUE
		var/message = "The <font color = 'red'>Soviets</font> and the <font color = 'green'> have captured the kishlak's compound! The Mujahideen have been wiped out!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_o = TRUE
		return FALSE
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <font color = 'red'>Soviet Army</font> and the <font color = 'green'>DRA</font> are capturing the Compound's Control Room! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <font color = 'red'>Soviet Army</font> and the <font color = 'green'>DRA</font> are capturing the Compound's Control Room! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "<font color = 'red'>Soviet Army</font> and the <font color = 'green'>DRA</font> are capturing the Compound's Control Room! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "<font color = 'red'>Soviet Army</font> and the <font color = 'green'>DRA</font> are capturing the Compound's Control Room! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <font color = 'black'>Mujahideen</font> have recaptured the Compound!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/magistral/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1 || H.faction_text == CIVILIAN)
				return TRUE
		else
			return !faction1_can_cross_blocks()
			return !faction2_can_cross_blocks()
	return FALSE