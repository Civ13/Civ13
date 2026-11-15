/obj/map_metadata/camp
	ID = MAP_CAMP
	title = "Camp"
	description = "A medieval King of the Hill battle between the French and English armies over a central castle."
	lobby_icon = "icons/lobby/medieval.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 0
	victory_time = 15000
	capture_objective_name = "Castle"
	capture_verb = "has"
	capture_notice_in_font = TRUE
	no_winner = "No faction controls the Castle."
	can_spawn_on_base_capture = TRUE

	faction_organization = list(
		BRITISH,
		FRENCH)

	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/island,
		list(FRENCH) = /area/caribbean/island
		)
	age = "1013"
	ordinal_age = 2
	faction_distribution_coeffs = list(BRITISH = 0.5, FRENCH = 0.5)
	songs = list(
		"Crusaders:1" = "sound/music/crusaders.ogg")
	battle_name = "battle of Normandy"
	mission_start_message = "<font size=4>The <b>French</b> and <b>English</b> armies are facing each other in Northern France! There is a <b>Castle</b> in the middle of the map, that must be captured and held for 8 minutes! The battle will start in <b>4 minutes</b>.</font>"
	faction1 = BRITISH
	faction2 = FRENCH
	ambience = list("sound/ambience/jungle1.ogg")
	gamemode = "King of the Hill"
	grace_wall_timer = 2400
/obj/map_metadata/camp/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/camp/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/camp/roundend_condition_def2name(define)
	..()
	switch (define)
		if (BRITISH)
			return "English"

/obj/map_metadata/camp/roundend_condition_def2army(define)
	..()
	switch (define)
		if (BRITISH)
			return "Kingdom of England"
		if (FRENCH)
			return "Kingdom of France"

/obj/map_metadata/camp/army2name(army)
	..()
	switch (army)
		if ("Kingdom of England")
			return "English"
		if ("Kingdom of France")
			return "French"


/obj/map_metadata/camp/cross_message(faction)
	if (faction == BRITISH)
		return "<font size = 4>The English may now cross the invisible wall!</font>"
	else if (faction == FRENCH)
		return "<font size = 4>The French may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/camp/reverse_cross_message(faction)
	if (faction == BRITISH)
		return "<span class = 'userdanger'>The English may no longer cross the invisible wall!</span>"
	else if (faction == FRENCH)
		return "<span class = 'userdanger'>The French may no longer cross the invisible wall!</span>"
	else
		return ""

/obj/map_metadata/camp/update_win_condition()
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

/obj/map_metadata/camp/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	return check_faction_grace_wall(H, T, faction1, faction2)
