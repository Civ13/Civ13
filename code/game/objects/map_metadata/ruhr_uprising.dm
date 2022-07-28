/obj/map_metadata/ruhr_uprising
	ID = MAP_RUHR_UPRISING
	title = "The Ruhr Uprising"
	lobby_icon = "icons/lobby/ruhr.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 1200
	no_hardcore = TRUE
	victory_time = 27000
	grace_wall_timer = 3000

	faction_organization = list(
		CIVILIAN,
		GERMAN)

	roundend_condition_sides = list(
		list(GERMAN) = /area/caribbean/german,
		list(CIVILIAN) = /area/caribbean/british/land/inside/objective,
		)
	age = "1920"
	ordinal_age = 5
	faction_distribution_coeffs = list(GERMAN = 0.4, CIVILIAN = 0.6)
	battle_name = "Battle for the Ruhr"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the battle begins!<br>The Ruhr Red Army will win if they hold out for <b>45 minutes</b>.<br>The Weimar Republic will win if they manage to capture the train station!</font>"
	faction1 = CIVILIAN
	faction2 = GERMAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Argonnerwaldlied:1" = "sound/music/argonnerwaldlied.ogg",)
	gamemode = "Siege"

/obj/map_metadata/ruhr_uprising/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_interwar)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/ruhr_uprising/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/ruhr_uprising/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/ruhr_uprising/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Ruhr Red Army"
		if (GERMAN)
			return "Weimar Republic"
/obj/map_metadata/ruhr_uprising/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Ruhr Red Army"
		if (GERMAN)
			return "Weimar Republic"

/obj/map_metadata/ruhr_uprising/army2name(army)
	..()
	switch (army)
		if ("CIVILIAN")
			return "Ruhr Red Army"
		if ("GERMAN")
			return "Weimar Republic"


/obj/map_metadata/ruhr_uprising/cross_message(faction)
	if (faction == GERMAN)
		return "<font size = 4>The Weimar Republic may now cross the invisible wall!</font>"
	else if (faction == CIVILIAN)
		return "<font size = 4>The Ruhr Red Army may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/ruhr_uprising/reverse_cross_message(faction)
	if (faction == GERMAN)
		return "<span class = 'userdanger'>The Weimar Republic may no longer cross the invisible wall!</span>"
	else if (faction == CIVILIAN)
		return ""
	else
		return ""


/obj/map_metadata/ruhr_uprising/update_win_condition()

	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Ruhr Red Army</b> has successfully defended the train station! The Weimar Republic has halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_o == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Weimar Republic</b> has captured the train station! The Ruhr Uprising has been crushed!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_o = TRUE
		return FALSE
	// Weimar major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Weimar Republic</b> has captured the train station! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Weimar minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Weimar Republic</b> has captured the train station! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// RRA major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Weimar Republic</b> has captured train station! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// RRA minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Weimar Republic</b> has captured the train station! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Ruhr Red Army</b> has recaptured the train station!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/ruhr_uprising/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/inside/two))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE