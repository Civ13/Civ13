/obj/map_metadata/fallujah
	ID = MAP_FALLUJAH
	title = "Fallujah"
	lobby_icon = "icons/lobby/fallujah.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/desert)
	respawn_delay = 1200
	no_winner = "The operation is still underway."

	faction_organization = list(
		ARAB,
		AMERICAN)

	roundend_condition_sides = list(
		list(ARAB) = /area/caribbean/arab,
		list(AMERICAN) = /area/caribbean/british
		)
	age = "2004"
	ordinal_age = 8

	faction_distribution_coeffs = list(ARAB = 0.5, AMERICAN = 0.5)
	battle_name = "Operation Phantom Fury"
	mission_start_message = "<font size=4>The <b>Insurgents</b> are holding the city. The <b>USMC</b> must clear out the area within <b>40 minutes</b>!</font>"
	faction1 = ARAB
	faction2 = AMERICAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"The Handsome Family - Far From Any Road:1" = "sound/music/farfromanyroad.ogg",)
	artillery_count = 3
	valid_artillery = list("Explosive")

/obj/map_metadata/fallujah/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 30000 || admin_ended_all_grace_periods)

/obj/map_metadata/fallujah/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


/obj/map_metadata/fallujah/roundend_condition_def2name(define)
	..()
	switch (define)
		if (ARAB)
			return "Insurents"
		if (AMERICAN)
			return "USMC"
/obj/map_metadata/fallujah/roundend_condition_def2army(define)
	..()
	switch (define)
		if (ARAB)
			return "Insurgents"
		if (AMERICAN)
			return "USMC"

/obj/map_metadata/fallujah/army2name(army)
	..()
	switch (army)
		if ("Insurgents")
			return "Insurgents"
		if ("USMC")
			return "US Marines"


/obj/map_metadata/fallujah/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The USMC may now cross the invisible wall!</font>"
	else if (faction == ARAB)
		return ""
	else
		return ""

/obj/map_metadata/fallujah/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The USMC may no longer cross the invisible wall!</span>"
	else if (faction == ARAB)
		return ""
	else
		return ""


var/no_loop_fj = FALSE

/obj/map_metadata/fallujah/update_win_condition()

	if (world.time >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The Insurgents pushed back the USMC from the city!"
		to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_fj == FALSE)
		ticker.finished = TRUE
		var/message = "The USMC has captured the city! The Insurgents retreat!"
		to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_arab = TRUE
		return FALSE
	else if (!capture_step(1, 2, 1.33, FALSE, ARAB, 1) && \
		!capture_step(1, 2, 1.01, FALSE, ARAB, 1) && \
		!capture_step(2, 1, 1.33, FALSE, AMERICAN, 1) && \
		!capture_step(2, 1, 1.01, FALSE, AMERICAN, 1))
		if (current_win_condition != no_winner && current_winner && current_loser)
			to_chat(world, "<font size = 3>The Insurgents reclaime their sector!</font>")
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash

/obj/map_metadata/fallujah/capture_message(id)
	switch (id)
		if (1)
			return "The USMC controls the main sector! They will win in {time} minutes."

	return TRUE