/obj/map_metadata/vojchi
	ID = MAP_VOJCHI
	title = "Sino Soviet Border conflict"
	lobby_icon = "icons/lobby/vojchi.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/taiga,/area/caribbean/no_mans_land/invisible_wall/taiga/two,/area/caribbean/no_mans_land/invisible_wall/taiga/one)
	respawn_delay = 1200
	no_winner ="The Radio station stays under soviet control, the PRC has halted the attack."
	no_hardcore = FALSE
	faction_organization = list(
		RUSSIAN,
		CHINESE)

	roundend_condition_sides = list(
		list(CHINESE) = /area/caribbean/british,
		list(RUSSIAN) = /area/caribbean/no_mans_land/capturable/one,
		)
	age = "1969"
	ordinal_age = 7
	faction_distribution_coeffs = list(CHINESE = 0.6, RUSSIAN = 0.4)
	battle_name = "Sino Soviet Border conflict"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!<br>The Soviets will win if they hold out for <b>45 minutes</b>. The Chinese will win if they manage to reach the <b>Radio Station</b> and hold it.</font>"
	faction1 = CHINESE
	faction2 = RUSSIAN
	grace_wall_timer = 3000
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Song of Zhenbao Island - Sino-Soviet War Song:1" = "sound/music/zhenbao.ogg",)
	gamemode = "Siege"

/obj/map_metadata/vojchi/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/chinese))
		if (J.is_sinosovbor)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/russian))
		if (J.is_sinosovbor)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/vojchi/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CHINESE)
			return "Chinese"
		if (RUSSIAN)
			return "Soviet"

/obj/map_metadata/vojchi/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CHINESE)
			return "Chinese"
		if (RUSSIAN)
			return "Soviets"

/obj/map_metadata/vojchi/army2name(army)
	..()
	switch (army)
		if ("Chinese")
			return "Chinese"
		if ("Soviets")
			return "Soviet"

/obj/map_metadata/vojchi/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>Both teams may now cross the invisible wall!</font>"
	else if (faction == CHINESE)
		return ""
	else
		return ""

/obj/map_metadata/vojchi/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>Both teams may no longer cross the invisible wall!</span>"
	else if (faction == CHINESE)
		return ""
	else
		return ""

/obj/map_metadata/vojchi/update_win_condition()

	if (world.time >= 27000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Soviets</b> Have successfully defended the radio station! The Chinese were halted!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_r == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Chinese</b> have captured the radio station! The battle for the Radio station is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_r = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Chinese</b> have reached the radio station! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Chinese</b> have reached the radio station! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Chinese</b> have reached the radio station! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Chinese</b> have reached the radio station! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Soviets</b> have recaptured the radio station!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/vojchi/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall/taiga))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/taiga/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/taiga/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
			return !faction2_can_cross_blocks()
	return FALSE