/obj/map_metadata/warsaw
	ID = MAP_WARSAW
	title = "Warsaw Uprising"
	lobby_icon = "icons/lobby/warsawup.png"
	no_winner = "The battle for the city of Warsaw is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 1200
	no_winner = "The HQ remains under Polish control."
	no_hardcore = TRUE
	faction_organization = list(
		GERMAN,
		POLISH)

	roundend_condition_sides = list(
		list(GERMAN) = /area/caribbean/british,
		list(POLISH) = /area/caribbean/no_mans_land/capturable/one,
		)
	age = "1944"
	ordinal_age = 6
	faction_distribution_coeffs = list(GERMAN = 0.5, POLISH = 0.5)

	battle_name = "Warsaw Uprising"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!<br>The Polish Home Army will win if they hold out for <b>45 minutes</b>.<br>The Wehrmacht will win if they manage to reach the <b>Radio Station</b> inside the Polish HQ.</font>"

	faction1 = GERMAN
	faction2 = POLISH
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"Song of The Warsaw Uprising - Chłopcy Silni Jak Stal (Boys Strong As Steel):1" = "sound/music/boysstrongassteel.ogg",)
	grace_wall_timer = 3000
	gamemode = "Siege"
	ambience = list('sound/ambience/battle1.ogg')
	no_hardcore = TRUE

/obj/map_metadata/warsaw/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/german/tank_crew))
		. = TRUE
	else if (J.is_warsawger == TRUE)
		. = TRUE
	else if (J.is_warpol == TRUE)
		. = TRUE
	else if (J.is_tanker == TRUE)
		. = FALSE
	else if (J.is_ww2 == TRUE && J.is_reichstag == FALSE)
		. = FALSE
	else if (J.is_reichstag == TRUE)
		. = FALSE
	else
		. = FALSE

/obj/map_metadata/warsaw/roundend_condition_def2name(define)
	..()
	switch (define)
		if (GERMAN)
			return "German"
		if (POLISH)
			return "Poland"
/obj/map_metadata/warsaw/roundend_condition_def2army(define)
	..()
	switch (define)
		if (GERMAN)
			return "Germans"
		if (POLISH)
			return "Polish"

/obj/map_metadata/warsaw/army2name(army)
	..()
	switch (army)
		if ("Germans")
			return "German"
		if ("Polish")
			return "Polish"

/obj/map_metadata/warsaw/cross_message(faction)
	if (faction == POLISH)
		return "<font size = 4>Both teams may now cross the invisible wall!</font>"
	else if (faction == GERMAN)
		return "<font size = 4>Both teams may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/warsaw/reverse_cross_message(faction)
	if (faction == POLISH)
		return "<span class = 'userdanger'>Both teams may no longer cross the invisible wall!</span>"
	else if (faction == GERMAN)
		return ""
	else
		return ""

/obj/map_metadata/warsaw/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 1200 // 2 minutes

/obj/map_metadata/warsaw/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/warsaw/update_win_condition()

	if (world.time >= 27000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Polish Home Army</b> has successfully defended the HQ! The city of Warsaw is liberated!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_r == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Germans</b> have captured the building! The battle for the city of Warsaw is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_r = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached the Central Hallway of the HQ! They will win in {time} minutes."
				next_win = world.time + short_win_time(POLISH)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached the Central Hallway of the HQ! They will win in {time} minutes."
				next_win = world.time + short_win_time(POLISH)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached the Central Hallway of the HQ! They will win in {time} minutes."
				next_win = world.time + short_win_time(POLISH)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached the Central Hallway of the HQ! They will win in {time} minutes."
				next_win = world.time + short_win_time(POLISH)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Polish</b> have recaptured the HQ!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/warsaw/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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
