/obj/map_metadata/long_march
	ID = MAP_LONG_MARCH
	title = "The Long March"
	lobby_icon = "icons/lobby/longmarch.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/tundra/one,/area/caribbean/no_mans_land/invisible_wall/inside,/area/caribbean/no_mans_land/invisible_wall/two)
	no_hardcore = TRUE
	respawn_delay = 1200
	faction_organization = list(
		CHINESE,
		CIVILIAN)

	roundend_condition_sides = list(
		list(CHINESE) = /area/caribbean/no_mans_land/tundra,
		list(CIVILIAN) = /area/caribbean/japanese/land/inside/command,
		)
	age = "1935"
	ordinal_age = 5
	faction_distribution_coeffs = list(CHINESE = 0.6, CIVILIAN = 0.4)
	battle_name = "The Long March"
	mission_start_message = "<font size=4>All factions have <b>8 minutes</b> to prepare before the ceasefire ends!<br>The Red Army will win if they manage to reach their destination up North, in the Mountains. They have <b>30 minutes</b> to do it before they get completely encircled by the National Army.</font>"
	faction1 = CHINESE
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Red Sun Up in the Sky:1" = "sound/music/redsun.ogg",)
	grace_wall_timer = 4800

/obj/map_metadata/long_march/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/chinese/captain) || istype(J, /datum/job/chinese/lieutenant) || istype(J, /datum/job/chinese/sergeant) || istype(J, /datum/job/chinese/doctor) || istype(J, /datum/job/chinese/infantry) || istype(J, /datum/job/chinese/sniper))
		. = TRUE
	else if (J.is_ccw == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/long_march/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Red Army"
		if (CHINESE)
			return "National Army"
/obj/map_metadata/long_march/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Red Army"
		if (CHINESE)
			return "National Army"

/obj/map_metadata/long_march/army2name(army)
	..()
	switch (army)
		if ("Civilian")
			return "Red Army"
		if ("Chinese")
			return "National Army"

/obj/map_metadata/long_march/cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 4>The Red Army may now cross the invisible wall!</font>"
	else if (faction == CHINESE)
		return ""
	else
		return ""

/obj/map_metadata/long_march/reverse_cross_message(faction)
	if (faction == CIVILIAN)
		return "<span class = 'userdanger'>The Red Army may no longer cross the invisible wall!</span>"
	else if (faction == CHINESE)
		return ""
	else
		return ""
var/no_loop_lm = FALSE

/obj/map_metadata/long_march/update_win_condition()
	if (world.time >= 18000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>National Army</b> have sucessfuly stopped the Red Army's retreat into the mountains."
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_lm == TRUE)
		ticker.finished = TRUE
		var/message = "The <b>Red Army</b> managed to reach their destination in time! The retreat has been succesful!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_nk = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Red Army</b> has reached its destination! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Red Army</b> has reached its destination! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Red Army</b> has reached its destination! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Red Army</b> has reached its destination! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>National Army</b> has pushed back the Red Army!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/long_march/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/tundra/one))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/inside))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
			return !faction2_can_cross_blocks()
	return FALSE
