/obj/map_metadata/nankou
	ID = MAP_NANKOU
	title = "Nankou"
	lobby_icon = "icons/lobby/china.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	no_hardcore = TRUE
	respawn_delay = 1200
	faction_organization = list(
		CHINESE,
		JAPANESE)

	roundend_condition_sides = list(
		list(CHINESE) = /area/caribbean/russian/land/inside/command,
		list(JAPANESE) = /area/caribbean/japanese/land/inside/command,
		)
	age = "1937"
	ordinal_age = 6
	faction_distribution_coeffs = list(CHINESE = 0.6, JAPANESE = 0.4)
	battle_name = "battle of Nankou"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!<br>The Japanese will win if they capture the <b>Train Station</b>. The Chinese will win if they manage to defend their command for <b>20 minutes!</b>.</font>"
	faction1 = CHINESE
	faction2 = JAPANESE
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Mugi to Heitai:1" = "sound/music/mugi_to_heitai.ogg",)
	grace_wall_timer = 3000

/obj/map_metadata/nankou/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_prison == TRUE || istype(J, /datum/job/japanese/ija_ww2ATunit) || J.is_pacific == TRUE || J.is_navy == TRUE || J.is_tanker == TRUE || J.is_samurai)
		. = FALSE
	else if (J.is_ww2 == TRUE)
		. = TRUE
	else if (istype(J, /datum/job/chinese/captain) || istype(J, /datum/job/chinese/lieutenant) || istype(J, /datum/job/chinese/sergeant) || istype(J, /datum/job/chinese/doctor) || istype(J, /datum/job/chinese/infantry) || istype(J, /datum/job/chinese/sniper))
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/nankou/roundend_condition_def2name(define)
	..()
	switch (define)
		if (JAPANESE)
			return "Japanese"
		if (CHINESE)
			return "Chinese"
/obj/map_metadata/nankou/roundend_condition_def2army(define)
	..()
	switch (define)
		if (JAPANESE)
			return "Japanese"
		if (CHINESE)
			return "Chinese"

/obj/map_metadata/nankou/army2name(army)
	..()
	switch (army)
		if ("Japanese")
			return "Japanese"
		if ("Chinese")
			return "Chinese"


/obj/map_metadata/nankou/cross_message(faction)
	if (faction == JAPANESE)
		return "<font size = 4>The Japanese may now cross the invisible wall!</font>"
	else if (faction == CHINESE)
		return ""
	else
		return ""

/obj/map_metadata/nankou/reverse_cross_message(faction)
	if (faction == JAPANESE)
		return "<span class = 'userdanger'>The Japanese may no longer cross the invisible wall!</span>"
	else if (faction == CHINESE)
		return ""
	else
		return ""
var/no_loop_nk = FALSE

/obj/map_metadata/nankou/update_win_condition()

	if (world.time >= 12000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Chinese</b> have sucessfuly defended the Nankou Train Station!! The Japanese have halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_nk == TRUE)
		ticker.finished = TRUE
		var/message = "The <b>Japanese</b> have captured the Nankou Train Station! The battle for Beiping is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_nk = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Japanese</b> have reached the Nankou Train Station! They will win in {time} minutes."
				next_win = world.time + short_win_time(JAPANESE)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Japanese</b> have reached the Nankou Train Station! They will win in {time} minutes."
				next_win = world.time + short_win_time(JAPANESE)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Japanese</b> have reached the Nankou Train Station! They will win in {time} minutes."
				next_win = world.time + short_win_time(JAPANESE)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Japanese</b> have reached the Nankou Train Station! They will win in {time} minutes."
				next_win = world.time + short_win_time(JAPANESE)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Chinese</b> have recaptured the Nankou Train Station!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/nankou/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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
		else
			return !faction2_can_cross_blocks()
	return FALSE
