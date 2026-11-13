/obj/map_metadata/rizal_stadium
	ID = MAP_RIZAL_STADIUM
	title = "Rizal Stadium"
	description = "The Japanese Army will win if they hold out for 20 minutes. The Americans will win if they manage to capture Japanese Command within Rizal Stadium!"
	lobby_icon = "icons/lobby/pacific.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 1200

	faction_organization = list(
		JAPANESE,
		AMERICAN)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/british,
		list(JAPANESE) = /area/caribbean/japanese/land/inside/command,
		)
	age = "1944"
	no_hardcore = TRUE
	ordinal_age = 6
	faction_distribution_coeffs = list(JAPANESE = 0.6, AMERICAN = 0.4)
	battle_name = "Rizal Stadium"
	mission_start_message = "<font size=4>All factions have <b>8 minutes</b> to prepare before the ceasefire ends!<br>The Japanese Army will win if they hold out for <b>20 minutes</b>. The Americans will win if they manage to capture Japanese Command within Rizal Stadium!</font>"
	faction1 = JAPANESE
	faction2 = AMERICAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Tokkutai Bushi (Koji Tsuruta):1" = "sound/music/tokkutai_bushi.ogg",)
	gamemode = "Siege"
	grace_wall_timer = 3600
/obj/map_metadata/rizal_stadium/roundend_condition_def2name(define)
	..()
	switch (define)
		if (JAPANESE)
			return "Japanese"
		if (AMERICAN)
			return "American"
/obj/map_metadata/rizal_stadium/roundend_condition_def2army(define)
	..()
	switch (define)
		if (JAPANESE)
			return "Japanese"
		if (AMERICAN)
			return "Americans"

/obj/map_metadata/rizal_stadium/army2name(army)
	..()
	switch (army)
		if ("Japanese")
			return "Japanese"
		if ("Americans")
			return "American"


/obj/map_metadata/rizal_stadium/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The Americans may now cross the invisible wall!</font>"
	else if (faction == JAPANESE)
		return ""
	else
		return ""

/obj/map_metadata/rizal_stadium/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The Americans may no longer cross the invisible wall!</span>"
	else if (faction == JAPANESE)
		return ""
	else
		return ""


var/no_loop_riz = FALSE

/obj/map_metadata/rizal_stadium/update_win_condition()

	if (world.time >= 13600)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Japanese</b> have successfully defended the Stadium! The Americans have halted the attack!"
		to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_riz == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Americans</b> have captured the Japanese Command! The battle for Rizal Stadium is over!"
		to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_riz = TRUE
		return FALSE
	else if (!capture_step(1, 2, 1.33, FALSE, AMERICAN, 1) && \
		!capture_step(1, 2, 1.01, FALSE, AMERICAN, 2) && \
		!capture_step(2, 1, 1.33, FALSE, AMERICAN, 1) && \
		!capture_step(2, 1, 1.01, FALSE, AMERICAN, 1))
		if (current_win_condition != no_winner && current_winner && current_loser)
			to_chat(world, "<font size = 3>The <b>Japanese</b> have recaptured the Stadium!</font>")
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/rizal_stadium/capture_message(id)
	switch (id)
		if (1)
			return "The <b>Americans</b> have captured the Japanese Command! They will win in {time} minutes."
		if (2)
			return "The <b>Americans</b> have captured the Japanese command! They will win in {time} minutes."

/obj/map_metadata/rizal_stadium/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	return check_faction_grace_wall(H, T, faction1, faction2)
