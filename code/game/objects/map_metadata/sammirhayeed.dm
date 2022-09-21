/obj/map_metadata/sammirhayeed
	ID = MAP_SAMMIRHAYEED
	title = "Sammir Hayeed"
	lobby_icon = "icons/lobby/medieval.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 300
	no_hardcore = TRUE
	faction_organization = list(
		ARAB,
		FRENCH)

	roundend_condition_sides = list(
		list(ARAB) = /area/caribbean/arab,
		list(FRENCH) = /area/caribbean/colonies,
		)
	age = "1013"
	ordinal_age = 3
	faction_distribution_coeffs = list(ARAB = 0.5, FRENCH = 0.5)
	battle_name = "battle of Sammir Hayeed"
	mission_start_message = "<font size=4>The <b>Crusaders</b> are besieging the <b>Arab</b> fortress of Sammir Hayeed! The Arabs will win if they manage to hold the fortress for 35 minutes. <br> The siege will start in <b>6 minutes</b>.</font>"
	faction1 = ARAB
	faction2 = FRENCH
	ambience = list('sound/ambience/desert.ogg')
	songs = list(
		"Crusaders:1" = "sound/music/crusaders.ogg")
	gamemode = "Siege"
	grace_wall_timer = 3600

/obj/map_metadata/sammirhayeed/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_crusader && J.is_medieval)
		. = TRUE
	else if (J.is_arabcaliph && J.is_medieval)
		. = TRUE
	else
		. = FALSE


/obj/map_metadata/sammirhayeed/roundend_condition_def2name(define)
	..()
	switch (define)
		if (FRENCH)
			return "Crusader"

/obj/map_metadata/sammirhayeed/roundend_condition_def2army(define)
	..()
	switch (define)
		if (FRENCH)
			return "Crusaders"

/obj/map_metadata/sammirhayeed/army2name(army)
	..()
	switch (army)
		if ("Crusaders")
			return "Crusader"


/obj/map_metadata/sammirhayeed/cross_message(faction)
	if (faction == ARAB)
		return "<font size = 4>The Arabs may now cross the invisible wall!</font>"
	else if (faction == FRENCH)
		return "<font size = 4>The Crusaders may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/sammirhayeed/reverse_cross_message(faction)
	if (faction == ARAB)
		return "<span class = 'userdanger'>The Arabs may no longer cross the invisible wall!</span>"
	else if (faction == FRENCH)
		return "<span class = 'userdanger'>The Crusaders may no longer cross the invisible wall!</span>"
	else
		return ""



var/no_loop_kar = FALSE

/obj/map_metadata/sammirhayeed/update_win_condition()

	if (world.time >= 21000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The Arabic Caliphate have managed to defend the fortress!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_kar == FALSE)
		ticker.finished = TRUE
		var/message = "The Crusaders have captured the fortress! The remaining Arabs have surrendered!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_kar = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Crusaders have the control over most of the Fortress! They will win in {time} minutes."
				next_win = world.time +  short_win_time(FRENCH)
				announce_current_win_condition()
				current_winner = "Crusaders"
				current_loser = "Arabic Caliphate"
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Crusaders have the control over most of the Fortress! They will win in {time} minutes."
				next_win = world.time +  short_win_time(FRENCH)
				announce_current_win_condition()
				current_winner = "Crusaders"
				current_loser = "Arabic Caliphate"
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition =  "The Crusaders have the control over most of the Fortress! They will win in {time} minutes."
				next_win = world.time +  short_win_time(ARAB)
				announce_current_win_condition()
				current_winner = "Crusaders"
				current_loser = "Arabic Caliphate"
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Crusaders have the control over most of the Fortress! They will win in {time} minutes."
				next_win = world.time + short_win_time(ARAB)
				announce_current_win_condition()
				current_winner = "Crusaders"
				current_loser = "Arabic Caliphate"
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The Arabs have recaptured the fortress!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/sammirhayeed/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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