/obj/map_metadata/arab_town
	ID = MAP_ARAB_TOWN
	title = "Arab Town"
	lobby_icon = "icons/lobby/modern.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/desert)
	respawn_delay = 1200
	no_winner = "The operation is still underway."
	description = "The IDF has launched an operation to capture a town held by Hezbollah. The IDF must capture the Hezbollah HQ (SW corner) within 40 minutes!"
	faction_organization = list(
		ARAB,
		AMERICAN)

	roundend_condition_sides = list(
		list(ARAB) = /area/caribbean/arab,
		list(AMERICAN) = /area/caribbean/british
		)
	age = "2006"
	ordinal_age = 8

	faction_distribution_coeffs = list(ARAB = 0.5, AMERICAN = 0.5)
	battle_name = "battle for the town"
	mission_start_message = "<font size=4>The <b>Hezbollah</b> is holding the town. <b>IDF</b> troops must capture the Hezbollah HQ (SW corner) within <b>40 minutes</b>!</font>"
	faction1 = ARAB
	faction2 = AMERICAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Al-Qussam:1" = "sound/music/alqassam.ogg",)
	artillery_count = 3
	valid_artillery = list("Explosive")

/obj/map_metadata/arab_town/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 30000 || admin_ended_all_grace_periods)

/obj/map_metadata/arab_town/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


/obj/map_metadata/arab_town/roundend_condition_def2name(define)
	..()
	switch (define)
		if (ARAB)
			return "Hezbollah"
		if (AMERICAN)
			return "IDF"
/obj/map_metadata/arab_town/roundend_condition_def2army(define)
	..()
	switch (define)
		if (ARAB)
			return "Hezbollah"
		if (AMERICAN)
			return "Israelis"

/obj/map_metadata/arab_town/army2name(army)
	..()
	switch (army)
		if ("Hezbollah")
			return "Hezbollah"
		if ("Israelis")
			return "IDF"


/obj/map_metadata/arab_town/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The IDF may now cross the invisible wall!</font>"
	else if (faction == ARAB)
		return ""
	else
		return ""

/obj/map_metadata/arab_town/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The IDF may no longer cross the invisible wall!</span>"
	else if (faction == ARAB)
		return ""
	else
		return ""


var/no_loop_arab = FALSE

/obj/map_metadata/arab_town/update_win_condition()

	if (world.time >= 24000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The Hezbollah has managed to defend their HQ!"
		to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_arab == FALSE)
		ticker.finished = TRUE
		var/message = "The IDF has captured Hezbollah's HQ! Hezbollah retreats!"
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
			to_chat(world, "<font size = 3>The Hezbollah has recaptured their HQ!</font>")
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/arab_town/capture_message(id)
	switch (id)
		if (1)
			return "The IDF controls the Hezbollah HQ! They will win in {time} minutes."

/obj/map_metadata/arab_town_2
	ID = MAP_ARAB_TOWN_2
	title = "Arab Town II"
	lobby_icon = "icons/lobby/modern.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/desert)
	respawn_delay = 1200
	description = "US Marines have launched an operation to capture a town held by insurgents. The Marines must capture the insurgent HQ (SW corner) within 40 minutes!"
	faction_organization = list(
		AMERICAN,
		ARAB)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/british,
		list(ARAB) = /area/caribbean/arab
		)
	age = "2006"
	ordinal_age = 8
	faction_distribution_coeffs = list(AMERICAN = 0.5, ARAB = 0.5)
	battle_name = "battle for the town"
	mission_start_message = "<font size=4>Capture most of the town and hold the enemy base! The grace wall will go down in <b>6 minutes</b>.</font>"
	faction1 = AMERICAN
	faction2 = ARAB
	valid_weather_types = list(WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Al-Qussam:1" = "sound/music/alqassam.ogg",)
	artillery_count = 3
	valid_artillery = list("Explosive")

/obj/map_metadata/arab_town_2/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/arab_town_2/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


/obj/map_metadata/arab_town_2/roundend_condition_def2name(define)
	..()
	switch (define)
		if (ARAB)
			return "Insurgent"
/obj/map_metadata/arab_town_2/roundend_condition_def2army(define)
	..()
	switch (define)
		if (ARAB)
			return "Insurgents"

/obj/map_metadata/arab_town_2/army2name(army)
	..()
	switch (army)
		if ("Insurgents")
			return "Insurgent"


/obj/map_metadata/arab_town_2/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>Both factions may now cross the invisible wall!</font>"
	else if (faction == ARAB)
		return ""
	else
		return ""

/obj/map_metadata/arab_town_2/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>Both factions may no longer cross the invisible wall!</span>"
	else if (faction == ARAB)
		return ""
	else
		return ""
