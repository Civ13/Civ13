/obj/map_metadata/missionary_ridge
	ID = MAP_MISSIONARY_RIDGE
	title = "Missionary Ridge"
	lobby_icon = "icons/lobby/missionary.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 0
	no_hardcore = TRUE

	faction_organization = list(
		AMERICAN,
		CIVILIAN)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/island,
		list(CIVILIAN) = /area/caribbean/russian/land/inside/command,
		)
	age = "1873"
	faction_distribution_coeffs = list(AMERICAN = 0.5, CIVILIAN = 0.5)
	battle_name = "Battle of Missionary Ridge"
	mission_start_message = "<font size=3>The <b>Union Army</b> and the <b>Confederate Army</b> are battling for the control of Missionary ridge! The Confederates will win if they hold their command for <b>30 minutes</b> The Union will win if the manage to hold the enemy command for <b>6 minutes</b>.<br>The battle will start in <b>5 minutes</b>.</font>"
	faction1 = AMERICAN
	faction2 = CIVILIAN
	ordinal_age = 4
	songs = list(
		"The Good the Bad the Ugly Theme:1" = "sound/music/good_bad_ugly.ogg")
	gamemode = "Siege"
	grace_wall_timer = 3000
/obj/map_metadata/missionary_ridge/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/american))
		if (J.is_civil_war)
			. = TRUE
		else
			. = FALSE
	if (istype(J, /datum/job/civilian))
		if (J.is_civil_war)
			. = TRUE
		else
			. = FALSE

/obj/map_metadata/missionary_ridge/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/missionary_ridge/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/missionary_ridge/roundend_condition_def2name(define)
	..()
	switch (define)
		if (AMERICAN)
			return "Union"
		if (CIVILIAN)
			return "Confederate"

/obj/map_metadata/missionary_ridge/roundend_condition_def2army(define)
	..()
	switch (define)
		if (AMERICAN)
			return "Union Army"
		if (CIVILIAN)
			return "Confederate Army"
/obj/map_metadata/missionary_ridge/army2name(army)
	..()
	switch (army)
		if ("Union")
			return "Union"
		if ("Confederate")
			return "Confederate"

/obj/map_metadata/missionary_ridge/cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 3>The Confederates may now cross the invisible wall!</font>"
	else if (faction == AMERICAN)
		return "<font size = 3>The Union may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/missionary_ridge/reverse_cross_message(faction)
	if (faction == CIVILIAN)
		return "<span class = 'userdanger'>The Confederates may no longer cross the invisible wall!</span>"
	else if (faction == AMERICAN)
		return "<span class = 'userdanger'>The Union may no longer cross the invisible wall!</span>"
	else
		return ""

/obj/map_metadata/missionary_ridge/update_win_condition()

	if (world.time >= 18000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Confederates Army</b> has sucessfuly defended Missionary Ridge! The Union have halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_r == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Union</b> have liberated Missionary Ridge! The battle for Missionary Ridge is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_r = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the Ridge! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the Ridge! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Ridge! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Ridge! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])

	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The [current_winner] has lost control of the Ridge!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/missionary_ridge/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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