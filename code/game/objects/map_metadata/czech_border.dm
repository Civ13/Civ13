
/obj/map_metadata/czech_border
	ID = MAP_czech_border
	title = "Battle On the Czech border"
	lobby_icon = "icons/lobby/ "
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/temperate,/area/caribbean/no_mans_land/invisible_wall/temperate/one,/area/caribbean/no_mans_land/invisible_wall/temperate/one)
	respawn_delay = 1200
	no_winner ="The Village is under Czech control."
	no_hardcore = TRUE
	faction_organization = list(
		WARPACT,
		NATO)
	roundend_condition_sides = list(
		list(WARPACT) =/area/caribbean/british,
		list(NATO) = /area/caribbean/no_mans_land/capturable,
		)
	age = "1971"
	ordinal_age = 7
	faction_distribution_coeffs = list(WARPACT = 0.5, NATO = 0.5)
	battle_name = "Battle "
	mission_start_message = "<font size=4>All factions have <b>8 minutes</b> to prepare before the ceasefire ends!<br>The Czechs will win if they hold the village for<b>40 minutes</b>. NATO will win if they reach and hold the Planning center.</font>"
	faction1 = WARPACT
	faction2 = NATO
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Red Army Choir - Katyusha:1" = "sound/music/putmusichere",)
	gamemode = "Siege"
	grace_wall_timer = 4800


obj/map_metadata/czech_border/roundend_condition_def2name(define)
	..()
	switch (define)
		if (WARPACT)
			return "warpact"
		if (NATO)
			return "nato"
/obj/map_metadata/czech_border/roundend_condition_def2army(define)
	..()
	switch (define)
		if (WARPACT)
			return "warpact"
		if (NATO)
			return "nato"

/obj/map_metadata/czech_border/army2name(army)
	..()
	switch (army)
		if ("Warpact")
			return "warpact"
		if ("Nato")
			return "nato"


/obj/map_metadata/czech_border/cross_message(faction)
	if (faction == NATO)
		return "<font size = 4>NATO may now cross the grace wall!</font>"
	else if (faction == WARPACT)
		return ""
	else
		return ""

/obj/map_metadata/czech_border/reverse_cross_message(faction)
	if (faction == NATO)
		return "<span class = 'userdanger'>NATO may no longer cross the grace wall!</span>"
	else if (faction == WARPACT)
		return ""
	else
		return ""


/obj/map_metadata/czech_border/update_win_condition()

	if (world.time >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Czechs</b> have sucessfuly defended The Village! NATO forces have halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_r == FALSE) //Needs to be looked into to prevent the bug of Germans "winning" by getting wiped and not respawning after 10 seconds.
		ticker.finished = TRUE
		var/message = "<b>NATO</b> has Captured the Village! The battle is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_r = TRUE
		return FALSE
	// russian major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = " <b>NATO</b> has reached The Planning Center! They will win in {time} minutes."
				next_win = world.time + short_win_time(GERMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// russian minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = " <b>NATO</b> has reached The Planning Center! They will win in {time} minutes."
				next_win = world.time + short_win_time(GERMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = " <b>NATO</b> has reached The Planning Center! They will win in {time} minutes."
				next_win = world.time + short_win_time(GERMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = " <b>NATO</b> has reached The Planning Center! They will win in {time} minutes."
				next_win = world.time + short_win_time(GERMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Czechs</b> have recaptured the Planning center!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/czech_border/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall/temperate))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/temperate/one))
			if (H.faction_text == faction1)
				return TRUE
		else
			return !faction1_can_cross_blocks()
			return !faction2_can_cross_blocks()
	return FALSE