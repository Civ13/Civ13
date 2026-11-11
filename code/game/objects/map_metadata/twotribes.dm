/obj/map_metadata/twotribes
	ID = MAP_TWOTRIBES
	title = "Two Tribes"
	description = "The Red and Blue tribes are engaged in battle, both attempting to capture the central shrine."
	lobby_icon = 'icons/lobby/civ13.gif'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle)
	respawn_delay = 0
	victory_time = 15000
	capture_objective_name = "Shrine"
	capture_verb = "has"
	capture_notice_in_font = TRUE
	has_hunger = TRUE
	no_winner = "No faction controls the Shrine."
	can_spawn_on_base_capture = TRUE

	faction_organization = list(
		BRITISH,
		FRENCH)

	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/island,
		list(FRENCH) = /area/caribbean/island
		)
	age = "Ab immemorabili"
	ordinal_age = 0
	faction_distribution_coeffs = list(BRITISH = 0.5, FRENCH = 0.5)
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	battle_name = "Battle of the Two Tribes"
	mission_start_message = "<font size=4>The <b>Red</b> and <b>Blue</b> tribes are engaged in battle, both attempting to capture the central shrine. Prepare for battle, it will begin in <b>5 minutes</b>!</font>"

	faction1 = BRITISH
	faction2 = FRENCH
	ambience = list("sound/ambience/jungle1.ogg")
	gamemode = "King of the Hill"
	grace_wall_timer = 2400

/obj/map_metadata/twotribes/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 1200
	else
		return 4800 // 8 minutes

/obj/map_metadata/twotribes/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 1200
	else
		return 4800 // 8 minutes

/obj/map_metadata/twotribes/roundend_condition_def2name(define)
	..()
	switch (define)
		if (BRITISH)
			return "Red Tribe"
		if (FRENCH)
			return "Blue Tribe"

/obj/map_metadata/twotribes/roundend_condition_def2army(define)
	..()
	switch (define)
		if (BRITISH)
			return "Red Tribe"
		if (FRENCH)
			return "Blue Tribe"

/obj/map_metadata/twotribes/army2name(army)
	..()
	switch (army)
		if ("Kingdom of England")
			return "Red Tribe"
		if ("Kingdom of France")
			return "Blue Tribe"


/obj/map_metadata/twotribes/cross_message(faction)
	if (faction == BRITISH)
		return "<font size = 4>The Red Tribe may now cross the invisible wall!</font>"
	else if (faction == FRENCH)
		return "<font size = 4>The Blue Tribe may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/twotribes/reverse_cross_message(faction)
	if (faction == ENGLISH)
		return "<span class = 'userdanger'>The Red Tribe may no longer cross the invisible wall!</span>"
	else if (faction == FRENCH)
		return "<span class = 'userdanger'>The Blue Tribe may no longer cross the invisible wall!</span>"
	else
		return ""

/obj/map_metadata/twotribes/update_win_condition()
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

/obj/map_metadata/twotribes/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	return check_two_sided_grace_wall(H, T)
