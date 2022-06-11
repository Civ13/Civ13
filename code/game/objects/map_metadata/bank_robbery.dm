/obj/map_metadata/bank_robbery
	ID = MAP_BANK_ROBBERY
	title = "Goldstein Bank"
	lobby_icon_state = "modern"
	caribbean_blocking_area_types = listlist(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two, /area/caribbean/no_mans_land/invisible_wall/inside)
	respawn_delay = 1200
	no_winner = "The robbery is still underway."
	faction_organization = list(
		CIVILIAN,
		BADGUYS)
	roundend_condition_sides = list(
		list(BADGUYS) = /area/caribbean/japanese/land/inside/command,
		)
	age = "1993"
	ordinal_age = 7
	faction_distribution_coeffs = list(CIVILIAN = 0.5, BADGUYS = 0.5)
	battle_name = "Goldstein Bank Heist"
	mission_start_message = "<font size=4>The robbers have <b>5 minutes</b> to prepare before the negotiations end!<br>The police will win if they capture the <b>Vault room inside the bank</b>. The Robbers will win if they manage to extract 1.000.000.000 from the vault within <b>15 minutes!</b></font>"
	faction1 = CIVILIAN
	faction2 = BADGUYS
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Woke Up This Morning:1" = "sound/music/woke_up_this_morning.ogg",)

/obj/map_metadata/bank_robbery/New()
	..()
	spawn(2500)
		if (gamemode == "Siege")
			for (var/turf/T in get_area_turfs(/area/caribbean/british/land/inside/objective))
				new /area/caribbean/no_mans_land/capturable(T)

/obj/map_metadata/bank_robbery/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_bank_robbery == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/bank_robbery/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/bank_robbery/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


/obj/map_metadata/bank_robbery/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Police"
		if (BADGUYS)
			return "Bad guys"
/obj/map_metadata/bank_robbery/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Police"
		if (BADGUYS)
			return "Robber"

/obj/map_metadata/bank_robbery/army2name(army)
	..()
	switch (army)
		if ("Police")
			return "Police"
		if ("Robber")
			return "Robber"

/obj/map_metadata/bank_robbery/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The Police may now cross the invisible wall!</font>"
	else if (faction == CIVILIAN)
		return ""
	else
		return ""

/obj/map_metadata/bank_robbery/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The Police may no longer cross the invisible wall!</span>"
	else if (faction == CIVILIAN)
		return ""
	else
		return ""
var/no_loop_bank_robbery = FALSE


/obj/map_metadata/bank_robbery/update_win_condition()
	var/message = ""

		if (world.time >= 12000)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			message = "The Robbers have managed to defend the Vault!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
		if ((current_winner && current_loser && world.time > next_win) && no_loop_bank_robbery == FALSE)
			ticker.finished = TRUE
			message = "The Police have captured the Vault!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			no_loop_bank_robbery = TRUE
			return FALSE
		// German major
		else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
			if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
				if (last_win_condition != win_condition.hash)
					current_win_condition = "The Police control the Vault! They will win in {time} minutes."
					next_win = world.time + short_win_time(CIVILIAN)
					announce_current_win_condition()
					current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
					current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
		// German minor
		else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
			if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
				if (last_win_condition != win_condition.hash)
					current_win_condition = "The Police control the Vault! They will win in {time} minutes."
					next_win = world.time + short_win_time(CIVILIAN)
					announce_current_win_condition()
					current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
					current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
		// Soviet major
		else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
			if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
				if (last_win_condition != win_condition.hash)
					current_win_condition = "The Police control the Vault! They will win in {time} minutes."
					next_win = world.time + short_win_time(AMERICAN)
					announce_current_win_condition()
					current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
					current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
		// Soviet minor
		else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
			if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
				if (last_win_condition != win_condition.hash)
					current_win_condition = "The Police control the Vault! They will win in {time} minutes."
					next_win = world.time + short_win_time(AMERICAN)
					announce_current_win_condition()
					current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
					current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
		else
			if (current_win_condition != no_winner && current_winner && current_loser)
				world << "<font size = 3>The Robbers has recaptured the Vault!</font>"
				current_winner = null
				current_loser = null
			next_win = -1
			current_win_condition = no_winner
			win_condition.hash = 0
		last_win_condition = win_condition.hash
		return TRUE

/obj/map_metadata/bank_robbery/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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

/obj/map_metadata/bank_robbery/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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