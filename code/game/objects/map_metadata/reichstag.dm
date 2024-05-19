
/obj/map_metadata/reichstag
	ID = MAP_REICHSTAG
	title = "Reichstag"
	lobby_icon = 'icons/lobby/reichstag.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 1200
	no_winner = "The Reichstag is still under German control."
	no_hardcore = TRUE
	faction_organization = list(
		GERMAN,
		RUSSIAN)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/british,
		list(GERMAN) = /area/caribbean/german/reichstag/roof/objective,
		)
	age = "1945"
	ordinal_age = 6
	faction_distribution_coeffs = list(GERMAN = 0.3, RUSSIAN = 0.7)
	battle_name = "Battle for the Reichstag"
	mission_start_message = "<font size=4>All factions have <b>6 minutes</b> to prepare before the ceasefire ends!<br>The Germans will win if they hold out for <b>40 minutes</b>. The Soviets will win if they manage to reach the top of the Reichstag.</font>"
	faction1 = GERMAN
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	grace_wall_timer = 3600 // 6 minutes
	songs = list(
		"Red Army Choir - Katyusha:1" = 'sound/music/katyusha.ogg',)
	gamemode = "Siege"

/obj/map_metadata/reichstag/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/german))
		if (J.is_ss_panzer == TRUE || J.is_tanker == TRUE)
			. = FALSE
		else if (J.is_ww2 == TRUE && J.is_reichstag == TRUE)
			. = TRUE
		else
			. = FALSE
	else
		if (istype(J, /datum/job/russian/antitank_soldier_soviet) || istype(J, /datum/job/russian/antitank_assistant_soldier_soviet))
			. = FALSE
		else if (J.is_ss_panzer == TRUE || J.is_tanker == TRUE)
			. = FALSE
		else if (J.is_ww2 == TRUE)
			. = TRUE
		else if (istype(J, /datum/job/russian/doctor))
			. = TRUE
		else
			. = FALSE

/obj/map_metadata/reichstag/roundend_condition_def2name(define)
	..()
	switch (define)
		if (GERMAN)
			return "German"
		if (RUSSIAN)
			return "Soviet"
/obj/map_metadata/reichstag/roundend_condition_def2army(define)
	..()
	switch (define)
		if (GERMAN)
			return "Germans"
		if (RUSSIAN)
			return "Soviets"

/obj/map_metadata/reichstag/army2name(army)
	..()
	switch (army)
		if ("Germans")
			return "German"
		if ("Soviets")
			return "Soviet"


/obj/map_metadata/reichstag/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The Soviets may now cross the invisible wall!</font>"
	else if (faction == GERMAN)
		return ""
	else
		return ""

/obj/map_metadata/reichstag/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Soviets may no longer cross the invisible wall!</span>"
	else if (faction == GERMAN)
		return ""
	else
		return ""


var/no_loop_r = FALSE

/obj/map_metadata/reichstag/update_win_condition()

	if (world.time >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Wehrmacht</b> has sucessfuly defended the Reichstag! The Soviets halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_r == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Soviets</b> have captured the Reichstag! The battle for Berlin is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_r = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Soviets</b> have reached the top of the Reichstag! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Soviets</b> have reached the top of the Reichstag! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Soviets</b> have reached the top of the Reichstag! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Soviets</b> have reached the top of the Reichstag! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Germans</b> have recaptured the Reichstag!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/reichstag/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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