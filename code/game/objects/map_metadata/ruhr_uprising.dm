/obj/map_metadata/ruhr_uprising
	ID = MAP_RUHR_UPRISING
	title = "The Ruhr Uprising"
	description = "The Ruhr Red Army will win if they hold out for 45 minutes.The Weimar Republic will win if they manage to capture the train station!"
	lobby_icon = "icons/lobby/ruhr.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 1200
	no_hardcore = TRUE
	victory_time = 27000
	grace_wall_timer = 3000

	faction_organization = list(
		CIVILIAN,
		GERMAN)

	roundend_condition_sides = list(
		list(GERMAN) = /area/caribbean/german,
		list(CIVILIAN) = /area/caribbean/british/land/inside/objective,
		)
	age = "1920"
	ordinal_age = 5
	faction_distribution_coeffs = list(GERMAN = 0.4, CIVILIAN = 0.6)
	battle_name = "Battle for the Ruhr"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the battle begins!<br>The Ruhr Red Army will win if they hold out for <b>45 minutes</b>.<br>The Weimar Republic will win if they manage to capture the train station!</font>"
	faction1 = CIVILIAN
	faction2 = GERMAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Argonnerwaldlied:1" = "sound/music/argonnerwaldlied.ogg",)
	gamemode = "Siege"

/obj/map_metadata/ruhr_uprising/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/ruhr_uprising/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/ruhr_uprising/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Ruhr Red Army"
		if (GERMAN)
			return "Weimar Republic"
/obj/map_metadata/ruhr_uprising/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Ruhr Red Army"
		if (GERMAN)
			return "Weimar Republic"

/obj/map_metadata/ruhr_uprising/army2name(army)
	..()
	switch (army)
		if ("CIVILIAN")
			return "Ruhr Red Army"
		if ("GERMAN")
			return "Weimar Republic"


/obj/map_metadata/ruhr_uprising/cross_message(faction)
	if (faction == GERMAN)
		return "<font size = 4>The Weimar Republic may now cross the invisible wall!</font>"
	else if (faction == CIVILIAN)
		return "<font size = 4>The Ruhr Red Army may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/ruhr_uprising/reverse_cross_message(faction)
	if (faction == GERMAN)
		return "<span class = 'userdanger'>The Weimar Republic may no longer cross the invisible wall!</span>"
	else if (faction == CIVILIAN)
		return ""
	else
		return ""


/obj/map_metadata/ruhr_uprising/update_win_condition()

	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Ruhr Red Army</b> has successfully defended the train station! The Weimar Republic has halted the attack!"
		to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_o == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Weimar Republic</b> has captured the train station! The Ruhr Uprising has been crushed!"
		to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_o = TRUE
		return FALSE
	else if (!capture_step(1, 2, 1.33, FALSE, AMERICAN, 1) && \
		!capture_step(1, 2, 1.01, FALSE, AMERICAN, 1) && \
		!capture_step(2, 1, 1.33, FALSE, AMERICAN, 2) && \
		!capture_step(2, 1, 1.01, FALSE, AMERICAN, 1))
		if (current_win_condition != no_winner && current_winner && current_loser)
			to_chat(world, "<font size = 3>The <b>Ruhr Red Army</b> has recaptured the train station!</font>")
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/ruhr_uprising/capture_message(id)
	switch (id)
		if (1)
			return "The <b>Weimar Republic</b> has captured the train station! They will win in {time} minutes."
		if (2)
			return "The <b>Weimar Republic</b> has captured train station! They will win in {time} minutes."

/obj/map_metadata/ruhr_uprising/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	return check_faction_grace_wall(H, T, faction1, faction2, two_area = /area/caribbean/no_mans_land/invisible_wall/inside/two)