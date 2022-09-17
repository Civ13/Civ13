
/obj/map_metadata/whiterun
	ID = MAP_WHITERUN
	title = "Whiterun"
	lobby_icon = "icons/lobby/tes13.png"
	no_winner ="The fighting is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 300
	no_hardcore = TRUE
	force_mapgen = TRUE
	faction_organization = list(
		ROMAN,
		CIVILIAN)

	roundend_condition_sides = list(
		list(ROMAN) = /area/caribbean/japanese/land/inside,
		list(CIVILIAN) = /area/caribbean/crusader,
		)
	age = "1013"
	ordinal_age = 3
	faction_distribution_coeffs = list(ROMAN = 0.5, CIVILIAN = 0.5)
	battle_name = "Siege of Whiterun"
	mission_start_message = "<font size=4>The <b>Stormcloaks</b> troops are besieging the <b>Imperial</b> City of <b>Whiterun</b>! The Imperials will win if they manage to hold the city for 30 minutes. <br> The siege will start in <b>6 minutes</b>.</font>"
	faction1 = ROMAN
	faction2 = CIVILIAN
	ambience = list('sound/ambience/desert.ogg')
	songs = list(
		"One They Fear:1" = "sound/music/tesonetheyfear.ogg",)
	gamemode = "Siege"
	grace_wall_timer = 3600

obj/map_metadata/whiterun/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/roman))
		if (J.is_skyrim && J.is_imperial)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/civilian))
		if (J.is_skyrim == TRUE && J.is_stormcloak == TRUE)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/whiterun/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Stormcloak"

/obj/map_metadata/whiterun/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Stormcloaks"

/obj/map_metadata/whiterun/army2name(army)
	..()
	switch (army)
		if ("Stormcloaks")
			return "Stormcloak"


/obj/map_metadata/whiterun/cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 4>The Stormcloaks may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/whiterun/reverse_cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 4>The Stormcloaks may no longer cross the invisible wall!</font>"
	else
		return ""



var/no_loop_whrn = FALSE

/obj/map_metadata/whiterun/update_win_condition()

	if (world.time >= 21000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The Imperials have managed to defend the city of Whiterun!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_whrn == FALSE)
		ticker.finished = TRUE
		var/message = "The Stormcloaks have captured the city of Whiterun! The remaining Imperials are retreating!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_whrn = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Stormcloaks have the control of Dragon's Reach! They will win in {time} minutes."
				next_win = world.time +  short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = "Stormcloaks"
				current_loser = "Imperials"
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Stormcloaks have the control of Dragon's Reach! They will win in {time} minutes."
				next_win = world.time +  short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = "Stormcloaks"
				current_loser = "Imperials"
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition =  "The Stormcloaks have the control of Dragon's Reach! They will win in {time} minutes."
				next_win = world.time +  short_win_time(ROMAN)
				announce_current_win_condition()
				current_winner = "Stormcloaks"
				current_loser = "Imperials"
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Stormcloaks have the control of Dragon's Reach! They will win in {time} minutes."
				next_win = world.time + short_win_time(ROMAN)
				announce_current_win_condition()
				current_winner = "Stormcloaks"
				current_loser = "Imperials"
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The Imperials have recaptured the city!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/whiterun/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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