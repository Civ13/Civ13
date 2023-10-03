/obj/map_metadata/syria
	ID = MAP_SYRIA
	title = "Syrian Civil War"
	lobby_icon = "icons/lobby/syria.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two, /area/caribbean/no_mans_land/invisible_wall/three)
	respawn_delay = 1200
	no_winner = "The operation is still underway."

	faction_organization = list(
		ARAB,
		AMERICAN)

	roundend_condition_sides = list(
		list(ARAB) = /area/caribbean/no_mans_land/capturable/one,
		list(AMERICAN) = /area/caribbean/no_mans_land/capturable/one
		)
	age = "2016"
	ordinal_age = 8
	faction_distribution_coeffs = list(ARAB = 0.5, AMERICAN = 0.5)
	battle_name = "Battle of Tadmur"
	mission_start_message = "<font size=4>The <b>Free Syrian Army</b> and the <b>Syrian Goverment forces</b> are battling against each other for the control of the Tadmur town!<br>Both sides have to capture and hold the Goverment Building for <b>6 minutes</b>.<br>The battle will start in <b>5 minutes</b>.</font>"
	faction1 = ARAB
	faction2 = AMERICAN
	songs = list(
		"God, Syria and Bashar!:1" = "sound/music/godsyriabashar.ogg")
	gamemode = "King of the Hill"

/obj/map_metadata/syria/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/syria/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/syria/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/arab))
		if (J.is_syria)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/american))
		if (J.is_syria)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/syria/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		if (clients.len < 10)
			return 1800 // 3 minutes
		else
			return 3000 // 5 minutes

/obj/map_metadata/syria/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		if (clients.len < 10)
			return 1800 // 3 minutes
		else
			return 3000 // 5 minutes

/obj/map_metadata/syria/roundend_condition_def2name(define)
	..()
	switch (define)
		if (ARAB)
			return "Syrian Armed Forces"
		if (AMERICAN)
			return "Free Syrian Army"
/obj/map_metadata/syria/roundend_condition_def2army(define)
	..()
	switch (define)
		if (ARAB)
			return "Syrian Armed Forces"
		if (AMERICAN)
			return "Free Syrian Army"

/obj/map_metadata/syria/army2name(army)
	..()
	switch (army)
		if ("Syrian Armed Forces")
			return "Syrian Armed Forces"
		if ("Free Syrian Army")
			return "Free Syrian Army"

/obj/map_metadata/syria/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The Free Syrian Army may now cross the invisible wall!</font>"
	else if (faction == ARAB)
		return "<font size = 4>The Syrian Armed Forces may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/syria/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The Free Syrian Army may no longer cross the invisible wall!</span>"
	else if (faction == ARAB)
		return "<span class = 'userdanger'>The Syrian Armed Forces may no longer cross the invisible wall!</span>"
	else
		return ""

/obj/map_metadata/syria/update_win_condition()

	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		if (current_winner && current_loser)
			message = "The battle is over! The [current_winner] was victorious over the [current_loser][battle_name ? " in the [battle_name]" : ""]!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		win_condition_spam_check = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] have captured the Goverment Building! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] have captured the Goverment Building! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Goverment Building! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Goverment Building! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])

	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The [current_winner] has lost control of the Government Building!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/syria/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/three))
			if (H.original_job.title == "Delta Force Operator")
				return TRUE
		else
			return !faction1_can_cross_blocks()
			return !faction2_can_cross_blocks()
	return FALSE