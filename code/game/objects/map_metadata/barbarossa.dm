/obj/map_metadata/barbarossa
	ID = MAP_BARBAROSSA
	title = "Start of operation Barbarossa"
	lobby_icon = "icons/lobby/barbarossa.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 1200
	no_winner ="The Border stays under Soviet control, stalling the German advance."
	no_hardcore = FALSE
	faction_organization = list(
		RUSSIAN,
		GERMAN)

	roundend_condition_sides = list(
		list(GERMAN) = /area/caribbean/british,
		list(RUSSIAN) = /area/caribbean/russian/land/outside,
		)
	age = "1941"
	ordinal_age = 6
	faction_distribution_coeffs = list(GERMAN = 0.6, RUSSIAN = 0.4)
	battle_name = "Start of operation barbarossa"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!<br>The Soviets will win if they hold out for <b>40 minutes</b>. The Germans will win if they manage to reach the <b>NKVD HQ</b> in the middle eastern part of the map.</font>"
	faction1 = GERMAN
	faction2 = RUSSIAN
	grace_wall_timer = 3000
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Red Army Choir - Cossacks Song:1" = "sound/music/cossacksong.ogg",)
	gamemode = "Siege"

/obj/map_metadata/barbarossa/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/russian/tank_crew))
		. = FALSE
	else if (J.is_ss_panzer == TRUE)
		. = FALSE
	else if (J.is_occupation == TRUE)
		. = FALSE
	else if (istype(J, /datum/job/german/tank_crew_leader))
		. = TRUE
	else if (istype(J, /datum/job/german/tank_crew))
		. = TRUE
	else if (J.is_ww2 == TRUE && J.is_reichstag == TRUE)
		. = FALSE
	else if (J.is_bordersov == TRUE)
		. = TRUE
	else if (J.is_borderger == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/barbarossa/roundend_condition_def2name(define)
	..()
	switch (define)
		if (GERMAN)
			return "German"
		if (RUSSIAN)
			return "Soviet"

/obj/map_metadata/barbarossa/roundend_condition_def2army(define)
	..()
	switch (define)
		if (GERMAN)
			return "Germans"
		if (RUSSIAN)
			return "Soviets"

/obj/map_metadata/barbarossa/army2name(army)
	..()
	switch (army)
		if ("Germans")
			return "German"
		if ("Soviets")
			return "Soviet"

/obj/map_metadata/barbarossa/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>Both teams may now cross the invisible wall!</font>"
	else if (faction == GERMAN)
		return ""
	else
		return ""

/obj/map_metadata/barbarossa/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>Both teams may no longer cross the invisible wall!</span>"
	else if (faction == GERMAN)
		return ""
	else
		return ""

/obj/map_metadata/barbarossa/update_win_condition()

	if (world.time >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Soviets</b> Have successfully defended the border! The Germans were halted!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_r == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Germans</b> have captured the HQ! the battle is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_r = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached the HQ! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached the HQ! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached the HQ! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached the HQ! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Soviets</b> have recaptured the HQ!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/barbarossa/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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