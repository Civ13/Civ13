/obj/map_metadata/bank_robbery
	ID = MAP_BANK_ROBBERY
	title = "The Goldstein Bank Heist"
	lobby_icon = "icons/lobby/bank_robbery.png"
	no_winner ="The robbery is still underway."
	caribbean_blocking_area_types = list(
		/area/caribbean/no_mans_land/invisible_wall,
		/area/caribbean/no_mans_land/invisible_wall/inside)
	respawn_delay = 0

	faction_organization = list(
		CIVILIAN,
		AMERICAN,)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/british/land/inside/objective,
		list(CIVILIAN) = /area/caribbean/japanese/land/inside/command, //doesn't exist on the map
		)

	age = "1996"
	ordinal_age = 7
	faction_distribution_coeffs = list(CIVILIAN = 0.65, AMERICAN = 0.35)
	battle_name = "Goldstein Bank Heist"
	mission_start_message = "<font size=4>The Robbers have <b>5 minutes</b> to prepare before the negotiations end!<br> The Police Department will win if they capture the <b>Vault Room inside the bank</b>. The Robbers will win if they manage to extract 10'000 dollars from the Vault within <b>25 minutes!</b></font>"
	faction1 = CIVILIAN
	faction2 = AMERICAN
	grace_wall_timer = 3000
	gamemode = "Bank Robbery"
	songs = list(
		"George Baker Selection - Little Green Bag:1" = "sound/music/little_green_bag.ogg",)

	var/list/civilians_evacuated = 0
	var/list/civilians_killed = list(
		"Police" = 0,
		"Robbers" = 0,
	)
/obj/map_metadata/bank_robbery/New()
	..()
	civ_collector()
	civ_status()
	civ_complete()

obj/map_metadata/bank_robbery/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_heist == TRUE)
		. = TRUE
		if(civilians_killed["Robbers"] >= 5 || civilians_evacuated == 12)
			if (J.title == "SWAT Officer")
				J.whitelisted = FALSE
				J.max_positions = 20
				J.total_positions = 20
	else if (J.title == "Paramedic")
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/bank_robbery/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/bank_robbery/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/bank_robbery/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Police Department"
		if (AMERICAN)
			return "Robbers"

/obj/map_metadata/bank_robbery/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Police Department"
		if (AMERICAN)
			return "Robbers"

/obj/map_metadata/bank_robbery/army2name(army)
	..()
	switch (army)
		if ("CIVILIAN")
			return "Police Department"
		if ("Americans")
			return "Robbers"

/obj/map_metadata/bank_robbery/cross_message(faction)
	return "<font size = 4>The Police Department has started the raid!</font>"

/obj/map_metadata/bank_robbery/reverse_cross_message(faction)
	return ""

/obj/map_metadata/bank_robbery/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 1200
	else
		return 1200 // 2 minutes

/obj/map_metadata/bank_robbery/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 1200
	else
		return 3000 // 2 minutes

/obj/map_metadata/bank_robbery/update_win_condition()
	if (processes.ticker.playtime_elapsed >= 18000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The Police Department has surrounded the whole neighborhood and are going in after each robber, one by one. The Robbers have failed their heist!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	else
		for(var/obj/structure/money_bag/C in world)
			if (C.storedvalue >= 10000) // total value stored = 12400+. So roughly 3/4th
				var/message = "The Robbers have sucessfully stolen over 10.000 dollars! The robbery was successful!"
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				show_global_battle_report(null)
				win_condition_spam_check = TRUE
				ticker.finished = TRUE
				return FALSE
		if ((current_winner && current_loser && world.time > next_win) && no_loop_o == FALSE)
			ticker.finished = TRUE
			world << "<font size = 4><span class = 'notice'>The Police Department seized total control of the Bank!</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			no_loop_o = TRUE
			return FALSE
		else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
			if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
				if (last_win_condition != win_condition.hash)
					current_win_condition = "The Police Department is now securing the Vault Room! They will win in {time} minutes."
					next_win = world.time + short_win_time(CIVILIAN)
					announce_current_win_condition()
					current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
					current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
		else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
			if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
				if (last_win_condition != win_condition.hash)
					current_win_condition = "The Police Department is now securing the Vault Room! They will win in {time} minutes."
					next_win = world.time + short_win_time(CIVILIAN)
					announce_current_win_condition()
					current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
					current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
		else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
			if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
				if (last_win_condition != win_condition.hash)
					current_win_condition = "The Police Department is now securing the Vault Room! They will win in {time} minutes."
					next_win = world.time + short_win_time(CIVILIAN)
					announce_current_win_condition()
					current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
					current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
		else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
			if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
				if (last_win_condition != win_condition.hash)
					current_win_condition = "The Police Department is now securing the Vault Room! They will win in {time} minutes."
					next_win = world.time + short_win_time(CIVILIAN)
					announce_current_win_condition()
					current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
					current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
		else
			if (current_win_condition != no_winner && current_winner && current_loser)
				world << "<font size = 3>The Robbers managed to regain control of the Vault Room!</font>"
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
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.original_job.is_outlaw == TRUE && !H.original_job.is_law == TRUE)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.original_job.is_law == TRUE && !H.original_job.is_outlaw == TRUE)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

/obj/map_metadata/bank_robbery/proc/civ_collector()
	for(var/turf/T in get_area_turfs(/area/caribbean/british/land/outside))
		for (var/mob/living/simple_animal/civilian/CVL in T)
			if(CVL.stat != DEAD)
				qdel(CVL)
				civilians_evacuated++
	spawn(600)
		civ_collector()
	return

/obj/map_metadata/bank_robbery/proc/civ_status()
	var/total_killed = (civilians_killed["Robbers"]+civilians_killed["Police"])
	spawn(2100)
		world << "<big>Evacuated hostages: [civilians_evacuated]/12 </big>"
		world << "<big>Dead hostages: [total_killed] </big>"
		civ_status()

/obj/map_metadata/bank_robbery/proc/civ_complete()
	var/spam_check = FALSE
	if (civilians_evacuated = 12)
		if (spam_check = FALSE)
			world << "<big><span class = 'notice'>The Police Department has successfully evacuated all the civilian hostages: Additional SWAT units are coming to assist!</span></big>"
			spam_check = TRUE
	civ_complete()