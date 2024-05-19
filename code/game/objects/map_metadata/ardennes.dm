/obj/map_metadata/ardennes
	ID = MAP_ARDENNES
	title = "Ardennes Offensive"
	lobby_icon = 'icons/lobby/ardennes.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/tundra,/area/caribbean/no_mans_land/invisible_wall/tundra/one,/area/caribbean/no_mans_land/invisible_wall/tundra/two)
	respawn_delay = 1200
	no_winner = "The HQ stays under American control, stalling the German offense."
	no_hardcore = TRUE
	faction_organization = list(
		AMERICAN,
		GERMAN)

	roundend_condition_sides = list(
		list(GERMAN) = /area/caribbean/british,
		list(AMERICAN) = /area/caribbean/no_mans_land/capturable/one,
		)
	age = "1944"
	ordinal_age = 6
	faction_distribution_coeffs = list(GERMAN = 0.6, AMERICAN = 0.4)
	battle_name = "Ardennes Offensive"
	mission_start_message = "<font size=4>All factions have <b>6 minutes</b> to prepare before the ceasefire ends!<br>The Americans will win if they hold out for <b>45 minutes</b>. The Germans will win if they manage to reach the <b>HQ</b> in the middle of the city.</font>"
	faction1 = AMERICAN
	faction2 = GERMAN
	grace_wall_timer = 3600
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Woody Guthrine - Tear the Fascists Down:1" = 'sound/music/tearthefascists.ogg',)
	gamemode = "Siege"

/obj/map_metadata/ardennes/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/german))
		if (J.is_ardennes)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/american))
		if (J.is_ardennes)
			. = TRUE
			if (istype(J, /datum/job/american/tanker_ww2))
				J.spawn_location = "JoinLateRN2" // Doing this because changing the spawn_loc in the job file will bust other maps
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/ardennes/roundend_condition_def2name(define)
	..()
	switch (define)
		if (GERMAN)
			return "German"
		if (AMERICAN)
			return "American"
/obj/map_metadata/ardennes/roundend_condition_def2army(define)
	..()
	switch (define)
		if (GERMAN)
			return "Germans"
		if (AMERICAN)
			return "Americans"

/obj/map_metadata/ardennes/army2name(army)
	..()
	switch (army)
		if ("Germans")
			return "German"
		if ("Americans")
			return "American"

/obj/map_metadata/ardennes/cross_message(faction)
	if (faction == AMERICAN)
		for (var/datum/job/J in job_master.occupations)
			if (J.is_ardennes)
				switch (J.title)
					if ("US Lieutenant")
						J.spawn_location = "JoinLateRNBoatswain2"
					if ("US Sergeant")
						J.spawn_location = "JoinLateRN2"
					if ("US Field Medic")
						J.spawn_location = "JoinLateRNSurgeon2"
					if ("US Doctor")
						J.spawn_location = "JoinLateRNSurgeon2"
					if ("US Sniper")
						J.spawn_location = "JoinLateRN2"
					if ("US Machine Gunner")
						J.spawn_location = "JoinLateRN2"
					if ("Ammo Bearer")
						J.spawn_location = "JoinLateRN2"
					if ("US Rifleman")
						J.spawn_location = "JoinLateRN2"
					if ("US Military Police")
						J.spawn_location = "JoinLateRNMidshipman2"
					
		return "<font size = 4>The German assault has begun!</font>"
	else if (faction == GERMAN)
		return ""
	else
		return ""

/obj/map_metadata/ardennes/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The Germans have halted their assault!</span>"
	else if (faction == GERMAN)
		return ""
	else
		return ""

/obj/map_metadata/ardennes/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600 // 1 minute
	else
		return 1200 // 2 minutes

/obj/map_metadata/ardennes/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600 // 1 minute
	else
		return 3000 // 5 minutes

var/no_loop_ar = FALSE
/obj/map_metadata/ardennes/update_win_condition()
	if (world.time >= 27000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Americans</b> Have successfully defended the HQ! The Germans were halted!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_ar == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Germans</b> have captured the building! The Battle of the Bulge is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_ar = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached the HQ! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached the HQ! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached the HQ! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Germans</b> have reached the HQ! They will win in {time} minutes."
				next_win = world.time + short_win_time(AMERICAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Americans</b> have recaptured the HQ!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/ardennes/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall/tundra))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/tundra/one))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/tundra/two))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
			return !faction2_can_cross_blocks()
	return FALSE