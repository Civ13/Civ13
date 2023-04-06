/obj/map_metadata/holdmadrid
	ID = MAP_HOLDMADRID
	title = "Siege of Madrid"
	lobby_icon = "icons/lobby/madrid.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 1200
	no_winner ="The Radio stays under Republican control."
	no_hardcore = FALSE
	faction_organization = list(
		SPANISH,
		CIVILIAN)

	roundend_condition_sides = list(
		list(SPANISH) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/no_mans_land/capturable/one,
		)
	age = "1936"
	ordinal_age = 6
	faction_distribution_coeffs = list(SPANISH = 0.5, CIVILIAN = 0.5)
	battle_name = "The siege of Madrid"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!<br>The Republicans will win if they hold out for <b>45 minutes</b>. The Nationalists will win if they manage to reach the <b>Radio Madrid</b> in the south eastern corner of the map.</font>"
	faction1 = SPANISH
	faction2 = CIVILIAN
	grace_wall_timer = 3000
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Banda Bassotti - Luna rossa:1" = "sound/music/lunarossa.ogg",)
	gamemode = "Siege"

obj/map_metadata/holdmadrid/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_spainciv == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/holdmadrid/roundend_condition_def2name(define)
	..()
	switch (define)
		if (SPANISH)
			return "Spain"
		if (CIVILIAN)
			return "Republican"

/obj/map_metadata/holdmadrid/roundend_condition_def2army(define)
	..()
	switch (define)
		if (SPANISH)
			return "Spanish"
		if (CIVILIAN)
			return "Republicans"

/obj/map_metadata/holdmadrid/army2name(army)
	..()
	switch (army)
		if ("Spanish")
			return "Spain"
		if ("Republicans")
			return "Republican"

/obj/map_metadata/holdmadrid/cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 4>Both teams may now cross the invisible wall!</font>"
	else if (faction == SPANISH)
		return ""
	else
		return ""

/obj/map_metadata/holdmadrid/reverse_cross_message(faction)
	if (faction == CIVILIAN)
		return "<span class = 'userdanger'>Both teams may no longer cross the invisible wall!</span>"
	else if (faction == SPANISH)
		return ""
	else
		return ""

/obj/map_metadata/holdmadrid/update_win_condition()

	if (world.time >= 27000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Republicans</b> Have successfully defended the Radio! The Nationalists were halted!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_r == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Nationalists</b> have captured the Radio! The battle for madrid is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_r = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Nationalists</b> have reached the Radio! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Nationalists</b> have reached the Radio! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Nationalists</b> have reached the Radio! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Nationalists</b> have reached the Radio! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Republicans</b> have recaptured the Radio station!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/holdmadrid/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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