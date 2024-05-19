/obj/map_metadata/marco_polo_bridge
	ID = MAP_MARCO_POLO_BRIDGE
	title = "Marco Polo Bridge"
	lobby_icon = 'icons/lobby/china.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 0
	can_spawn_on_base_capture = TRUE

	faction_organization = list(
		JAPANESE,
		CHINESE)

	roundend_condition_sides = list(
		list(JAPANESE) = /area/caribbean/island,
		list(CHINESE) = /area/caribbean/island,
		)
	age = "1937"
	faction_distribution_coeffs = list(JAPANESE = 0.4, CHINESE = 0.6)
	battle_name = "The Marco Polo Birdge Incident"
	mission_start_message = "<font size=4>The <b>Imperial Japanese Army</b> and the <b>Kuomintang</b> are battling for the control of Marco Polo Bridge! Each side will win if they manage to hold the <b>central island</b> for <b>4 minutes</b>.<br>The battle will start in <b>4 minutes</b>.</font>"
	faction1 = JAPANESE
	faction2 = CHINESE
	ordinal_age = 6
	songs = list(
		"Mugi to Heitai:1" = 'sound/music/mugi_to_heitai.ogg',
		"I Hate These Classes:2" = 'sound/music/i_hate_these_classes.ogg')
	gamemode = "King of the Hill"
/obj/map_metadata/marco_polo_bridge/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 2400 || admin_ended_all_grace_periods)

/obj/map_metadata/marco_polo_bridge/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 2400 || admin_ended_all_grace_periods)

/obj/map_metadata/marco_polo_bridge/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_prison == TRUE || istype(J, /datum/job/japanese/ija_ww2ATunit) || J.is_pacific == TRUE || J.is_navy == TRUE || J.is_tanker == TRUE)
		. = FALSE
	else if (J.is_ww2 == TRUE)
		. = TRUE
	else if (istype(J, /datum/job/chinese/captain) || istype(J, /datum/job/chinese/lieutenant) || istype(J, /datum/job/chinese/sergeant) || istype(J, /datum/job/chinese/doctor) || istype(J, /datum/job/chinese/infantry) || istype(J, /datum/job/chinese/sniper))
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/marco_polo_bridge/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 2400
	else
		return 2400 // 4 minutes

/obj/map_metadata/marco_polo_bridge/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 2400
	else
		return 2400 // 4 minutes

/obj/map_metadata/marco_polo_bridge/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CHINESE)
			return "Chinese"
		if (JAPANESE)
			return "Japanese"

/obj/map_metadata/marco_polo_bridge/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CHINESE)
			return "Chinese Army"
		if (JAPANESE)
			return "Japanese Army"
/obj/map_metadata/marco_polo_bridge/army2name(army)
	..()
	switch (army)
		if ("Chinese")
			return "Chinese"
		if ("Japanese")
			return "Japanese"

/obj/map_metadata/marco_polo_bridge/cross_message(faction)
	if (faction == JAPANESE)
		return "<font size = 4>The Japanese may now cross the invisible wall!</font>"
	else if (faction == CHINESE)
		return "<font size = 4>The Chinese may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/marco_polo_bridge/reverse_cross_message(faction)
	if (faction == JAPANESE)
		return "<span class = 'userdanger'>The Japanese may no longer cross the invisible wall!</span>"
	else if (faction == CHINESE)
		return "<span class = 'userdanger'>The Chinese may no longer cross the invisible wall!</span>"
	else
		return ""

/obj/map_metadata/marco_polo_bridge/update_win_condition()

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
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the Island! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the Island! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Island! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Island! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])

	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The [current_winner] has lost control of the Island!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/marco_polo_bridge/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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