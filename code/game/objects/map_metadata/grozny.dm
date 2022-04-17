/obj/map_metadata/grozny
	ID = MAP_GROZNY
	title = "Retreat From Grozny"
	lobby_icon_state = "grozny"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 1200
	no_hardcore = TRUE
	faction_organization = list(
		CHECHEN,
		RUSSIAN)
	roundend_condition_sides = list(
		list(CHECHEN) = /area/caribbean/japanese/land,
		list(RUSSIAN) = /area/caribbean/british,
		)
	age = "1996"
	ordinal_age = 8 // instead of 7 in order to get the russian icons above the players
	faction_distribution_coeffs = list(CHECHEN = 0.67, RUSSIAN = 0.33)
	battle_name = "Retreat From Grozny"
	mission_start_message = "<font size=4>All factions have <b>8 minutes</b> to prepare before the ceasefire ends!<br>The Chechen Militia will win if they hold out the retreat for <b>30 minutes</b>. The Russian Federal Forces will win if they manage to cross the bridge south of the city into friendly territory!</font>"
	faction2 = RUSSIAN
	faction1 = CHECHEN
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Just don't tell mom I'm in Chechnya:1" = "sound/music/just_dont_tell_mom_im_in_chechnya.ogg",)
	artillery_count = 3 //they really need it to get anywhere, but now it's some OP shit
	artillery_timer = 2400 //and they need it just slightly quicker. It's artillery supposedly, not CAS.
	valid_artillery = list("Explosive","Napalm","Creeping Barrage")
/obj/map_metadata/grozny/New()
	..()
	spawn(20)
		for(var/obj/structure/lamp/O)
			if (prob(25))
				O.on = TRUE
				O.powerneeded = FALSE
			if (prob(20))
				O.lamp_broken = TRUE
		for(var/obj/structure/curtain/NC)
			if ((NC.icon_state != "open") && prob(15))
				NC.icon_state = "open"
				NC.opacity = FALSE


/obj/map_metadata/grozny/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_grozny == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/grozny/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)

/obj/map_metadata/grozny/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)


/obj/map_metadata/grozny/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CHECHEN)
			return "Chechens"
		if (RUSSIAN)
			return "Russians"
/obj/map_metadata/grozny/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CHECHEN)
			return "Chechens"
		if (RUSSIAN)
			return "Russians"

/obj/map_metadata/grozny/army2name(army)
	..()
	switch (army)
		if ("Chechens")
			return "Chechen"
		if ("Russians")
			return "Russian"


/obj/map_metadata/grozny/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The Russian Federal Forces may now cross the invisible wall!</font>"
	else if (faction == CHECHEN)
		return ""
	else
		return ""

/obj/map_metadata/grozny/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Russian Federal Forces may no longer cross the invisible wall!</span>"
	else if (faction == CHECHEN)
		return ""
	else
		return ""


	no_loop_ret = FALSE

/obj/map_metadata/grozny/update_win_condition()
	if (world.time >= 18000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Chechens</b> have successfuly deterred the withdrawal! The Russian Federal Forces failed the retreat!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_ret == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Russian Federal Forces</b> have crossed the bridge into friendly territory! The retreat is succesful!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_ret = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Russian Federal Forces</b> have crossed the bridge into friendly territory! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Russian Federal Forces</b> have crossed the bridge into friendly territory! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Russian major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Russian Federal Forces</b> have crossed the bridge into friendly territory! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Russian minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Russian Federal Forces</b> have crossed the bridge into friendly territory! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>Oddly the <b>Russian Federal Forces</b> have retreated back into enemy territory!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/grozny/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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
			return !faction1_can_cross_blocks()
	return FALSE