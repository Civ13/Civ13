/obj/map_metadata/nyadzonya
	ID = MAP_NYADZONYA
	title = "Nyadzonya"
	lobby_icon_state = "coldwar"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two, /area/caribbean/no_mans_land/invisible_wall/inside)
	respawn_delay = 1200
	no_hardcore = TRUE

	faction_organization = list(
		INDIANS,
		AMERICAN)

	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/no_mans_land/capturable,
		list(AMERICAN) = /area/caribbean/japanese/land/inside/command,
		)
	age = "1976"
	ordinal_age = 7
	faction_distribution_coeffs = list(INDIANS = 0.3, AMERICAN = 0.7)
	battle_name = "The Nyadzonya raid"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!<br>The Rhodesian forces will win if they capture the <b>ZANLA's paradegrounds</b>. The ZANLA forces will win if they manage to defend their paradegrounds <b>20 minutes!</b></font>"
	faction1 = CIVILIAN
	faction2 = AMERICAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Rhodesians Never Die (Clem Tholet):1" = "sound/music/rhodesians_never_die.ogg",)

/obj/map_metadata/nyadzonya/New()
	..()
	spawn(2500)
		if (gamemode == "Siege")
			for (var/turf/T in get_area_turfs(/area/caribbean/british/land/inside/objective))
				new /area/caribbean/no_mans_land/capturable(T)
/obj/map_metadata/waco/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_waco == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/nyadzonya/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/nyadzonya/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


/obj/map_metadata/nyadzonya/roundend_condition_def2name(define)
	..()
	switch (define)
		if (AMERICAN)
			return "Rhodesian"
		if (INDIANS)
			return "Zanla"
/obj/map_metadata/nyadzonya/roundend_condition_def2army(define)
	..()
	switch (define)
		if (AMERICAN)
			return "Rhodesian"
		if (INDIANS)
			return "Zanla"

/obj/map_metadata/nyadzonya/army2name(army)
	..()
	switch (army)
		if ("Rhodesian")
			return "Rhodesian"
		if ("Zanla")
			return "Zanla"


/obj/map_metadata/nyadzonya/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The Rhodesians may now cross the invisible wall!</font>"
	else if (faction == CIVILIAN)
		return ""
	else
		return ""

/obj/map_metadata/nyadzonya/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The Rhodesians may no longer cross the invisible wall!</span>"
	else if (faction == CIVILIAN)
		return ""
	else
		return ""
var/no_loop_nyadzonya = FALSE


/obj/map_metadata/nyadzonya/update_win_condition()

	if (world.time >= 18000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Zanla forces</b> have sucessfuly defended the base! The Rhodesians have halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_n == TRUE)
		ticker.finished = TRUE
		var/message = "The <b>Rhodesians</b> have captured the Zanla base! The battle for the Zanla base is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_n = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Rhodesians</b> have reached the paradegrounds! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Rhodesians</b> have reached the paradegrounds! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Rhodesians</b> have reached the paradegrounds! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Rhodesians</b> have reached the paradegrounds! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Chinese</b> have recaptured the Nanjing Command!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/nyadzonya/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one) && processes.ticker.playtime_elapsed <= 3000)
			if (H.faction_text == faction2 || H.faction_text == faction1)
				return TRUE
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/inside))
			if (H.faction_text == faction2)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1)
				return TRUE
		else
			return !faction2_can_cross_blocks()
	return FALSE