/obj/map_metadata/oasis
	ID = MAP_OASIS
	title = "Trouble at the Oasis"
	description = "The Crusader and Arabic Caliphate armies have found each other by chance in the desert as they searched for a water source."
	lobby_icon = "icons/lobby/medieval.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 0
	victory_time = 15000
	capture_objective_name = "Oasis"
	capture_verb = "has"
	capture_notice_in_font = TRUE
	no_winner = "No faction controls the Oasis."
	can_spawn_on_base_capture = TRUE

	faction_organization = list(
		FRENCH,
		ARAB)

	roundend_condition_sides = list(
		list(FRENCH) = /area/caribbean/island,
		list(ARAB) = /area/caribbean/island
		)
	age = "1013"
	ordinal_age = 2
	faction_distribution_coeffs = list(FRENCH = 0.5, ARAB = 0.5)
	songs = list(
		"Crusaders:1" = "sound/music/crusaders.ogg")
	battle_name = "Trouble at the Oasis"
	mission_start_message = "<font size=4>The <b>Crusader</b> and <b>Arabic Caliphate</b> armies have found each other by chance in the desert as they searched for a water source. Each group is thirsty and seeking to secure the valuable Oasis for themselves. Whichever army manages to hold onto the shores of the Oasis for 5 minutes will capture it. Grace wall will end in 4 minutes."
	faction1 = FRENCH
	faction2 = ARAB
	ambience = list("sound/ambience/jungle1.ogg")
	gamemode = "King of the Oasis"
	grace_wall_timer = 2400


/obj/map_metadata/oasis/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/oasis/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes


/obj/map_metadata/oasis/roundend_condition_def2name(define)
	..()
	switch (define)
		if (FRENCH)
			return "Crusader"
		if (ARAB)
			return "Arabic Caliphate"

/obj/map_metadata/oasis/roundend_condition_def2army(define)
	..()
	switch (define)
		if (FRENCH)
			return "Crusaders"
		if (ARAB)
			return "Arabic Caliphate"

/obj/map_metadata/oasis/cross_message(faction)
	if (faction == ARAB)
		return "<font size = 4>The Arabic Caliphate may now cross the invisible wall!</font>"
	else if (faction == FRENCH)
		return "<font size = 4>The Crusaders may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/oasis/reverse_cross_message(faction)
	if (faction == ARAB)
		return "<span class = 'userdanger'>The Arabic Caliphate may no longer cross the invisible wall!</span>"
	else if (faction == FRENCH)
		return "<span class = 'userdanger'>The Crusaders may no longer cross the invisible wall!</span>"
	else
		return ""

/obj/map_metadata/oasis/update_win_condition()
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if (capture_countdown_elapsed())
		return FALSE
	update_capture_state()
	return TRUE


/obj/map_metadata/oasis/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	return check_faction_grace_wall(H, T, faction1, faction2)
