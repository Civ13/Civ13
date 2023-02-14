/obj/map_metadata/detroit
	ID = MAP_DETROIT
	title = "Detroit"
	lobby_icon = "icons/lobby/detroit.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 1200
	no_winner ="Detroit stays under crackhead control."
	no_hardcore = FALSE
	faction_organization = list(
		CIVILIAN,
		AMERICAN)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british,
		list(AMERICAN) = /area/caribbean/no_mans_land/capturable/one,
		)
	age = "2025"
	ordinal_age = 8
	faction_distribution_coeffs = list(CIVILIAN = 0.4, AMERICAN = 0.6)
	battle_name = "The siege of detroit"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!<br>The crackheads will win if they hold out for <b>30 minutes</b>. The UN will win if they reach the south eastern part of the city in the building.</font>"
	faction1 = CIVILIAN
	faction2 = AMERICAN
	grace_wall_timer = 3000
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Red Army Choir - cortex-napalm sticks to kids:1" = "sound/music/napalmsticsktokidsbycortex.ogg",)
	gamemode = "Siege"

/obj/map_metadata/detroit/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_detroit == FALSE)
		. = TRUE
	else if (J.is_1713 == TRUE)
		. = FALSE
	else if (J.is_un == TRUE)
		. = FALSE
	else
		. = FALSE

/obj/map_metadata/detroit/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Civilian"
		if (AMERICAN)
			return "American"

/obj/map_metadata/detroit/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Civilian"
		if (AMERICAN)
			return "American"

/obj/map_metadata/detroit/army2name(army)
	..()
	switch (army)
		if ("Civilians")
			return "Civilian"
		if ("Americans")
			return "American"

/obj/map_metadata/detroit/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The UN may now cross the invisible wall!</font>"
	else if (faction == CIVILIAN)
		return ""
	else
		return ""

/obj/map_metadata/detroit/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>Both teams may no longer cross the invisible wall!</span>"
	else if (faction == CIVILIAN)
		return ""
	else
		return ""

/obj/map_metadata/detroit/update_win_condition()

	if (world.time >= 18000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Crackheads</b> Have successfully defended the building! The UN is retreating!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_r == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>UN</b> has captured the building, the battle is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_r = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>UN</b> has reached the building! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>UN</b> has reached the building! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>UN</b> has reached the building! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>UN</b> has reached the building! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>crackheads</b> have recaptured the building!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/detroit/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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
			return !faction2_can_cross_blocks()
	return FALSE