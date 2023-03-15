/obj/map_metadata/tantiveiv
	ID = MAP_TANTIVEIV
	title = "VantiveIV"
	lobby_icon = "icons/lobby/galacticbattles.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/one, /area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 1200
	no_hardcore = TRUE

	faction_organization = list(
		CIVILIAN,
		AMERICAN)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/japanese/land/inside/command,
		)
	age = "A long long time ago"
	ordinal_age = 8
	faction_distribution_coeffs = list(CIVILIAN = 0.7, AMERICAN = 0.3)
	battle_name = "VantiveIV capture"
	mission_start_message = "<font size=4>All factions have <b>4 minutes</b> to prepare before the boarding begins!<br>The Alliance to Restore the Democracy will win if they hold out for <b>20 minutes</b>. The Extra-Galactic Empire will win if they manage to capture the Alliance Spawn within the Bridge of the Vantive IV!</font>"
	faction1 = CIVILIAN
	faction2 = AMERICAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Battle of Heroes (Galactic Battles):1" = "sound/music/battle_of_heroes.ogg",)
	gamemode = "Siege"
	grace_wall_timer = 2400
/obj/map_metadata/tantiveiv/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/american))
		if (J.is_starwars && J.is_empire)
			. = TRUE
		else
			.= FALSE
	if (istype(J, /datum/job/civilian))
		if (J.is_starwars && J.is_rebel)
			. = TRUE
		else
			. = FALSE


/obj/map_metadata/tantiveiv/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Rebellion"
		if (AMERICAN)
			return "Empire"
/obj/map_metadata/tantiveiv/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Rebels"
		if (AMERICAN)
			return "Imperials"

/obj/map_metadata/tantiveiv/army2name(army)
	..()
	switch (army)
		if ("Rebels")
			return "Rebellion"
		if ("Impierals")
			return "Empire"


/obj/map_metadata/tantiveiv/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The Imperial Shocktroopers may now cross the invisible wall!</font>"
	else if (faction == JAPANESE)
		return ""
	else
		return ""

/obj/map_metadata/tantiveiv/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The Imperial Shocktroopers may no longer cross the invisible wall!</span>"
	else if (faction == JAPANESE)
		return ""
	else
		return ""


var/no_loop_tantive = FALSE

/obj/map_metadata/tantiveiv/update_win_condition()

	if (world.time >= 14400)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Rebellion</b> has successfuly defended the Vantive IV bridge! The Rebels have halted the Imperial Shocktroopers from Boarding!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_tantive == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Imperials</b> have captured the Vantive IV Bridge!! The commandeering of the Vantive IV has been achieved!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_tantive = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Imperials</b> have captured the Vantive IV Bridge! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Imperials</b> have captured the Vantive IV Bridge! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Imperials</b> have captured the Vantive IV Bridge! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Imperials</b> have captured the Vantive IV Bridge! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Rebellion</b> has recaptured the Vantive IV!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/tantiveiv/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE