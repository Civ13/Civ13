/obj/map_metadata/elaia
	ID = MAP_ELAIA
	title = "Elaia"
	lobby_icon = "icons/lobby/ww2.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 0
	no_hardcore = TRUE

	faction_organization = list(
		GREEK,
		ITALIAN)

	roundend_condition_sides = list(
		list(GREEK) = /area/caribbean/greek,
		list(ITALIAN) = /area/caribbean/island,
		)
	age = "1940"
	faction_distribution_coeffs = list(GREEK = 0.5, ITALIAN = 0.5)
	battle_name = "Battle of Elaia-Kalamas"
	mission_start_message = "<font size=3>The <b>Royal Italian Army</b> and the <b>Hellenic Army</b> are battling for the control of Port Arthur! The Greeks will win if they hold the line for <b>30 minutes</b> The Italians will win if the manage to hold the line for <b>5 minutes</b>.<br>The battle will start in <b>5 minutes</b>.</font>"
	faction1 = GREEK
	faction2 = ITALIAN
	ordinal_age = 5
	songs = list(
		"Bella Ciao:1" = "sound/music/bella_ciao.ogg")
	gamemode = "Siege"

/obj/map_metadata/elaia/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 36000 || admin_ended_all_grace_periods)

/obj/map_metadata/elaia/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/elaia/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/greek))
		if (J.is_ww2)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/italian))
		if (J.is_ww2)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/elaia/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/elaia/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/elaia/roundend_condition_def2name(define)
	..()
	switch (define)
		if (GREEK)
			return "Greeks"
		if (ITALIAN)
			return "Italians"

/obj/map_metadata/elaia/roundend_condition_def2army(define)
	..()
	switch (define)
		if (GREEK)
			return "Hellenic Army"
		if (ITALIAN)
			return "Japanese Army"
/obj/map_metadata/elaia/army2name(army)
	..()
	switch (army)
		if ("Greeks")
			return "Greek"
		if ("Italians")
			return "Italian"

/obj/map_metadata/elaia/cross_message(faction)
	if (faction == GREEK)
		return "<font size = 3>The Italians may now cross the invisible wall!</font>"
	else if (faction == ITALIAN)
		return "<font size = 3>The Italians may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/elaia/reverse_cross_message(faction)
	if (faction == GREEK)
		return "<span class = 'userdanger'>The Italians may no longer cross the invisible wall!</span>"
	else if (faction == ITALIAN)
		return "<span class = 'userdanger'>The Italians may no longer cross the invisible wall!</span>"
	else
		return ""

/obj/map_metadata/elaia/update_win_condition()

	if (world.time >= 18000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Greeks</b> has sucessfuly defended Elaia! The Italians have halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_arth == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Italians</b> have captured Elaia! The Battle of Elaia-Kalamas is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_arth = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the Elaia river line! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the Elaia river line!! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Elaia river line! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Elaia river line! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])

	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The [current_winner] has lost control of the Elaia river line!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/elaia/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction2)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction1)
				return TRUE
		else
			return !faction2_can_cross_blocks()
	return FALSE