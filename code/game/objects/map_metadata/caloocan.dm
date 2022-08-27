/obj/map_metadata/caloocan
	ID = MAP_CALOOCAN
	title = "Caloocan"
	lobby_icon = "icons/lobby/ph_us_war.png"
	no_winner ="The church is under Filipino control."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 600

	faction_organization = list(
		FILIPINO,
		AMERICAN)

	roundend_condition_sides = list(
		list(FILIPINO) = /area/caribbean/japanese/land/inside/command,
		list(AMERICAN) = /area/caribbean/japanese/land/inside/command,
		)
	age = "1899"
	ordinal_age = 5
	faction_distribution_coeffs = list(FILIPINO = 0.6, AMERICAN = 0.4)
	battle_name = "battle of caloocan"
	mission_start_message = "<font size=4>All factions have <b>4 minutes</b> to prepare before the ceasefire ends!<br>The <b>Armies</b> will win if they capture the <b>Chruch!</b>.</font>"
	faction1 = FILIPINO
	faction2 = AMERICAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	gamemode = "King of the Hill"
	grace_wall_timer = 2400
/obj/map_metadata/caloocan/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_ph_us_war == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/caloocan/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/caloocan/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes
/obj/map_metadata/caloocan/roundend_condition_def2name(define)
	..()
	switch (define)
		if (FILIPINO)
			return "Filipino"
		if (AMERICAN)
			return "American"
/obj/map_metadata/caloocan/roundend_condition_def2army(define)
	..()
	switch (define)
		if (FILIPINO)
			return "Philippine Republic Army"
		if (AMERICAN)
			return "American Army"

/obj/map_metadata/caloocan/army2name(army)
	..()
	switch (army)
		if ("American Army")
			return "American"
		if ("Philippine Republic Army")
			return "Filipino"


/obj/map_metadata/caloocan/cross_message(faction)
	if (faction == AMERICAN)
		return ""
	else if (faction == FILIPINO)
		return "<font size = 4>The Armies may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/caloocan/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return ""
	else if (faction == FILIPINO)
		return "<font size = 4>The Armies may no longer cross the invisible wall!</font>"
	else
		return ""


var/no_loop_cal = FALSE

/obj/map_metadata/caloocan/update_win_condition()

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
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] have captured the Church! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] have captured the Church! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] have captured the Church! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] have captured the Church! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])

	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The [current_winner] have lost control of the Church!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/caloocan/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE
