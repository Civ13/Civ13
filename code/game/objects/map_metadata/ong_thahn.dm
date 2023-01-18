/obj/map_metadata/ong_thahn
	ID = MAP_ONG_THAHN
	title = "Battle of Ong Thahn"
	lobby_icon = "icons/lobby/vietnam.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle/one, /area/caribbean/no_mans_land/invisible_wall/jungle/two)
	victory_time = 27000
	no_winner = "The FOB is still held by the US Army."
	no_hardcore = TRUE

	faction_organization = list(
		AMERICAN,
		VIETNAMESE)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/no_mans_land/jungle,
		list(VIETNAMESE) = /area/caribbean/japanese,
		)

	age = "1967"
	ordinal_age = 7
	faction_distribution_coeffs = list(AMERICAN = 0.5, VIETNAMESE = 0.5)
	battle_name = "Battle of Ong Thahn"
	mission_start_message = "<font size=4>The <b>NVA</b> must capture the American FOB. The <b>US Army</b> must defend their base for <b>45 minutes</b>.<br>All factions have <b>6 minutes</b> to prepare before the combat starts.</font>"
	faction1 = AMERICAN
	faction2 = VIETNAMESE
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Fortunate Son:1" = "sound/music/fortunate_son.ogg",)
	artillery_count = 3
	grace_wall_timer = 3600
	gamemode = "Siege"

/obj/map_metadata/ong_thahn/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/vietnamese))
		if (J.is_nva)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/american))
		if (J.is_coldwar && !J.is_specops && !J.is_modernday)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/ong_thahn/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/ong_thahn/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/ong_thahn/roundend_condition_def2name(define)
	..()
	switch (define)
		if (VIETNAMESE)
			return "NVA"
		if (AMERICAN)
			return "American"

/obj/map_metadata/ong_thahn/roundend_condition_def2army(define)
	..()
	switch (define)
		if (VIETNAMESE)
			return "NVA"
		if (AMERICAN)
			return "Americans"

/obj/map_metadata/ong_thahn/army2name(army)
	..()
	switch (army)
		if ("VIETNAMESE")
			return "NVA"
		if ("Americans")
			return "American"


/obj/map_metadata/ong_thahn/cross_message(faction)
	if (faction == VIETNAMESE)
		return "<font size = 4>The NVA may now cross the invisible wall!</font>"
	else if (faction == AMERICAN)
		return ""
	else
		return ""

/obj/map_metadata/ong_thahn/reverse_cross_message(faction)
	if (faction == VIETNAMESE)
		return "<span class = 'userdanger'>The NVA may no longer cross the invisible wall!</span>"
	else if (faction == AMERICAN)
		return ""
	else
		return ""

/obj/map_metadata/ong_thahn/update_win_condition()
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		world << "<font size = 4><span class = 'notice'>The US Army has managed to defend the FOB! The NVA retreats back!</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_o == FALSE)
		ticker.finished = TRUE
		world << "<font size = 4><span class = 'notice'>The NVA has captured the FOB!</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_o = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The NVA controls the FOB! They will win in {time} minutes."
				next_win = world.time + short_win_time(VIETNAMESE)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The NVA controls the FOB! They will win in {time} minutes."
				next_win = world.time + short_win_time(VIETNAMESE)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The NVA controls the FOB! They will win in {time} minutes."
				next_win = world.time + short_win_time(VIETNAMESE)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The NVA controls the FOB! They will win in {time} minutes."
				next_win = world.time + short_win_time(VIETNAMESE)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The US Army has recaptured the FOB!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/ong_thahn/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle/one))
			if (H.faction_text == faction1)
				return TRUE
			return !faction1_can_cross_blocks()
	return FALSE


