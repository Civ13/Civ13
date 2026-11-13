// The Ides of March, 44 B.C. Caesar's party against the conspirators in and
// around the Curia of Pompey. The conspirators win the moment Caesar dies;
// Caesar's party wins if he is still alive when time runs out.

#define IDES_TIME_LIMIT 12000 // 20 minutes of play.

/area/caribbean/ides
	name = "Streets of Rome"
	icon_state = "purple1"
	base_turf = /turf/floor/plating/cobblestone
	climate = "temperate"

/area/caribbean/ides/curia
	name = "Curia of Pompey"
	icon_state = "red1"
	location = AREA_INSIDE

/area/caribbean/ides/house
	name = "Domus"
	icon_state = "red2"
	location = AREA_INSIDE

/obj/map_metadata/ides_of_march
	ID = MAP_IDES_OF_MARCH
	title = "The Ides of March"
	description = "Senators with hidden daggers wait for Caesar in the Curia of Pompey. Kill him, or keep him alive for 20 minutes."
	lobby_icon = "icons/lobby/ancient.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 1200
	no_winner = "Caesar still lives."
	no_hardcore = TRUE
	gamemode = "Ides of March"
	gamemode_vote = FALSE

	faction_organization = list(
		ROMAN,
		CIVILIAN)

	roundend_condition_sides = list(
		list(ROMAN) = /area/caribbean/ides/house,
		list(CIVILIAN) = /area/caribbean/ides/curia,
		)
	age = "44 B.C."
	ordinal_age = 1
	faction_distribution_coeffs = list(ROMAN = 0.45, CIVILIAN = 0.55)
	battle_name = "the Ides of March"
	mission_start_message = "<font size=4>The fifteenth day of March, 44 B.C. The senate meets in the Curia of Pompey. The doors open in <b>2 minutes</b>.<br>The conspirators win if <b>Caesar dies</b>. Caesar's party wins if he is <b>alive after 20 minutes</b>.</font>"
	faction1 = ROMAN
	faction2 = CIVILIAN
	grace_wall_timer = 1200
	valid_weather_types = list(WEATHER_NONE)
	songs = list(
		"Divinitus:1" = "sound/music/divinitus.ogg",)
	var/list/caesars = list()

/obj/map_metadata/ides_of_march/roundend_condition_def2name(define)
	..()
	switch (define)
		if (ROMAN)
			return "Caesarian"
		if (CIVILIAN)
			return "Liberator"

/obj/map_metadata/ides_of_march/roundend_condition_def2army(define)
	..()
	switch (define)
		if (ROMAN)
			return "Caesar's Party"
		if (CIVILIAN)
			return "Liberatores"

/obj/map_metadata/ides_of_march/army2name(army)
	..()
	switch (army)
		if ("Caesar's Party")
			return "Caesarian"
		if ("Liberatores")
			return "Liberator"

/obj/map_metadata/ides_of_march/cross_message(faction)
	if (faction == ROMAN)
		return "<font size = 4>The doors of the Curia are open. Caesar enters the senate.</font>"
	return ""

/obj/map_metadata/ides_of_march/reverse_cross_message(faction)
	return ""

// TRUE once a Caesar has joined and every Caesar is dead.
/obj/map_metadata/ides_of_march/proc/caesar_fallen()
	if (!caesars.len)
		return FALSE
	for (var/mob/living/human/H in caesars)
		if (!QDELETED(H) && H.stat != DEAD)
			return FALSE
	return TRUE

/obj/map_metadata/ides_of_march/proc/end_ides(message)
	ticker.finished = TRUE
	next_win = -1
	current_win_condition = no_winner
	win_condition.hash = 0
	last_win_condition = win_condition.hash
	win_condition_spam_check = TRUE
	to_chat(world, "<font size = 4 color='yellow'><span class = 'notice'>[message]</span></font>")
	show_global_battle_report(null)

/obj/map_metadata/ides_of_march/update_win_condition()
	if (win_condition_spam_check)
		return FALSE
	if (caesar_fallen())
		current_winner = roundend_condition_def2army(CIVILIAN)
		current_loser = roundend_condition_def2army(ROMAN)
		end_ides("Caesar is dead! The Liberatores have struck down the Dictator.")
		return FALSE
	if (processes.ticker.playtime_elapsed >= IDES_TIME_LIMIT)
		current_winner = roundend_condition_def2army(ROMAN)
		current_loser = roundend_condition_def2army(CIVILIAN)
		end_ides("The day is over and Caesar still lives! The plot has failed.")
		return FALSE
	return TRUE

#undef IDES_TIME_LIMIT
