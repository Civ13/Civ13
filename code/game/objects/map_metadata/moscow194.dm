/obj/map_metadata/siegemoscow
	ID = MAP_SIEGEMOSCOW
	title = "Siege of Moscow"
	lobby_icon = "icons/lobby/ww2.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/tundra,/area/caribbean/no_mans_land/invisible_wall/tundra/one,/area/caribbean/no_mans_land/invisible_wall/tundra/two)
	respawn_delay = 1200
	no_winner ="The Politburo is under Soviet control."
	no_hardcore = TRUE
	faction_organization = list(
		RUSSIAN,
		GERMAN)
	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/no_mans_land/capturable,
		list(GERMAN) = /area/caribbean/british,
		)
	age = "1942"
	ordinal_age = 6
	faction_distribution_coeffs = list(RUSSIAN = 0.5, GERMAN = 0.5)
	battle_name = "Battle for Moscow"
	mission_start_message = "<font size=4>All factions have <b>8 minutes</b> to prepare before the ceasefire ends!<br>The Russians will win if they hold out for <b>40 minutes</b>. The Germans will win if they manage to reach and hold the Politburo in the Administration building!</font>"
	faction1 = RUSSIAN
	faction2 = GERMAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Red Army Choir - Katyusha:1" = "sound/music/katyusha.ogg",)
	gamemode = "Siege"
	grace_wall_timer = 4800

/obj/map_metadata/siegemoscow/job_enabled_specialcheck(var/datum/job/J)
	..()
	if ((J.is_ww2 == TRUE && J.is_reichstag == FALSE && J.is_occupation == FALSE) || J.is_smallsiegemoscow == TRUE)
		. = TRUE
	else if (J.is_ss_panzer == TRUE)
		. = TRUE
	else if (istype(J, /datum/job/german/mediziner) || istype(J, /datum/job/russian/doctor_soviet))
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/siegemoscow/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Soviet"
		if (GERMAN)
			return "German"
/obj/map_metadata/siegemoscow/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Soviet"
		if (GERMAN)
			return "Germans"

/obj/map_metadata/siegemoscow/army2name(army)
	..()
	switch (army)
		if ("Soviets")
			return "Soviet"
		if ("Germans")
			return "German"


/obj/map_metadata/siegemoscow/cross_message(faction)
	if (faction == GERMAN)
		return "<font size = 4>The Germans may now cross the invisible wall!</font>"
	else if (faction == RUSSIAN)
		return ""
	else
		return ""

/obj/map_metadata/siegemoscow/reverse_cross_message(faction)
	if (faction == GERMAN)
		return "<span class = 'userdanger'>The Germans may no longer cross the invisible wall!</span>"
	else if (faction == RUSSIAN)
		return ""
	else
		return ""


/obj/map_metadata/siegemoscow/update_win_condition()
	if (world.time >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Soviets</b> have sucessfuly defended Moscow! The Germans stopped the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_r == FALSE) //Needs to be looked into to prevent the bug of Germans "winning" by getting wiped and not respawning after 10 seconds.
		ticker.finished = TRUE
		var/message = "The <b>Germans</b> have captured Moscow! The Siege of Moscow is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_r = TRUE
		return FALSE
	// russian major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached The Politburo! They will win in {time} minutes."
				next_win = world.time + short_win_time(GERMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// russian minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached The Politburo! They will win in {time} minutes."
				next_win = world.time + short_win_time(GERMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached The Politburo! They will win in {time} minutes."
				next_win = world.time + short_win_time(GERMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached The Politburo! They will win in {time} minutes."
				next_win = world.time + short_win_time(GERMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Soviets</b> have recaptured the Politburo!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/siegemoscow/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall/tundra))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/tundra/one))
			if (H.faction_text == faction1)
				return TRUE
		else
			return !faction1_can_cross_blocks()
			return !faction2_can_cross_blocks()
	return FALSE


///////////////////////////////////////////////////////////
////////////////////////////////SMALLSEIGE/////////////////
///////////////////////////////////////////////////////////

/obj/map_metadata/smallsiegemoscow
	ID = MAP_SMALLSIEGEMOSCOW
	title = "Central Siege of Moscow"
	lobby_icon = "icons/lobby/ww2.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/tundra,/area/caribbean/no_mans_land/invisible_wall/tundra/one,/area/caribbean/no_mans_land/invisible_wall/tundra/two)
	respawn_delay = 1200
	no_winner ="The Politburo is under Soviet control."
	no_hardcore = TRUE
	faction_organization = list(
		RUSSIAN,
		GERMAN)
	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/no_mans_land/capturable,
		list(GERMAN) = /area/caribbean/british,
		)
	age = "1942"
	ordinal_age = 6
	faction_distribution_coeffs = list(RUSSIAN = 0.5, GERMAN = 0.5)
	battle_name = "Battle for Moscow"
	mission_start_message = "<font size=4>All factions have <b>8 minutes</b> to prepare before the ceasefire ends!<br>The Russians will win if they hold out for <b>40 minutes</b>. The Germans will win if they manage to reach and hold the Politburo in the Administration building!</font>"
	faction1 = RUSSIAN
	faction2 = GERMAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Red Army Choir - Katyusha:1" = "sound/music/katyusha.ogg",)
	gamemode = "Siege"
	grace_wall_timer = 4800

/obj/map_metadata/smallsiegemoscow/job_enabled_specialcheck(var/datum/job/J)
	..()
	if ((J.is_ww2 == TRUE && J.is_reichstag == FALSE && J.is_occupation == FALSE) || J.is_smallsiegemoscow == TRUE)
		. = TRUE
	else if (J.is_ss_panzer == TRUE)
		. = TRUE
	else if (istype(J, /datum/job/german/mediziner) || istype(J, /datum/job/russian/doctor_soviet))
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/smallsiegemoscow/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Soviet"
		if (GERMAN)
			return "German"
/obj/map_metadata/smallsiegemoscow/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Soviet"
		if (GERMAN)
			return "Germans"

/obj/map_metadata/smallsiegemoscow/army2name(army)
	..()
	switch (army)
		if ("Soviets")
			return "Soviet"
		if ("Germans")
			return "German"


/obj/map_metadata/smallsiegemoscow/cross_message(faction)
	if (faction == GERMAN)
		return "<font size = 4>The Germans may now cross the invisible wall!</font>"
	else if (faction == RUSSIAN)
		return ""
	else
		return ""

/obj/map_metadata/smallsiegemoscow/reverse_cross_message(faction)
	if (faction == GERMAN)
		return "<span class = 'userdanger'>The Germans may no longer cross the invisible wall!</span>"
	else if (faction == RUSSIAN)
		return ""
	else
		return ""

/obj/map_metadata/smallsiegemoscow/update_win_condition()
	if (world.time >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Soviets</b> have sucessfuly defended Moscow! The Germans stopped the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_r == FALSE) //Needs to be looked into to prevent the bug of Germans "winning" by getting wiped and not respawning after 10 seconds.
		ticker.finished = TRUE
		var/message = "The <b>Germans</b> have captured Moscow! The Siege of Moscow is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_r = TRUE
		return FALSE
	// russian major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached The Politburo! They will win in {time} minutes."
				next_win = world.time + short_win_time(GERMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// russian minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached The Politburo! They will win in {time} minutes."
				next_win = world.time + short_win_time(GERMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached The Politburo! They will win in {time} minutes."
				next_win = world.time + short_win_time(GERMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached The Politburo! They will win in {time} minutes."
				next_win = world.time + short_win_time(GERMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Soviets</b> have recaptured the Politburo!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/smallsiegemoscow/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall/tundra))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/tundra/one))
			if (H.faction_text == faction1)
				return TRUE
		else
			return !faction1_can_cross_blocks()
			return !faction2_can_cross_blocks()
	return FALSE
