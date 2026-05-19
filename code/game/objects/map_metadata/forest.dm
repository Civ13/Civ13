/obj/map_metadata/forest
	ID = MAP_FOREST
	title = "Forest"
	description = "The Wehrmacht and Red Army are facing each other in the forests of Ukraine! The russians may cross after 15 minutes! It will start in 7 minutes."
	lobby_icon = "icons/lobby/ww2.png"
	no_winner ="The battle for the city is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/not_dynamic, /area/caribbean/no_mans_land/invisible_wall/one, /area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 300
	faction_organization = list(
		GERMAN,
		RUSSIAN,
		CIVILIAN
		)
	roundend_condition_sides = list(
		list(GERMAN) = /area/caribbean/german/inside/objective,
		list(RUSSIAN) = /area/caribbean/russian/land/inside/command,
		list(CIVILIAN) = /area/caribbean/british/land/inside,
		)
	age = "1943"
	songs = list(
		"Red Army Choir - Katyusha:1" = "sound/music/katyusha.ogg",)
	ordinal_age = 6
	faction_distribution_coeffs = list(GERMAN = 0.5, RUSSIAN = 0.5, CIVILIAN = 0.2)
	battle_name = "Forest"
	mission_start_message = "<font size=4>The <b>Wehrmacht</b> and <b>Red Army</b> are facing each other in the forests of Ukraine! The russians may cross after 15 minutes! It will start in <b>7 minutes</b>.</font>"
	faction1 = GERMAN
	faction2 = RUSSIAN
	var/gracedown1 = TRUE
/obj/map_metadata/forest/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 9000 || admin_ended_all_grace_periods)

/obj/map_metadata/forest/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4200 || admin_ended_all_grace_periods)

/obj/map_metadata/forest/cross_message(faction)
	if (faction == GERMAN)
		return "<font size = 4>The Germans may now cross!</font>"
	else if (faction == RUSSIAN)
		return "<font size = 4>The Soviets may now cross!</font>"
	else
		return ""

/obj/map_metadata/forest/reverse_cross_message(faction)
	if (faction == GERMAN)
		return "<font size = 4>The Germans may no longer cross!,</font>"
	else if (faction == RUSSIAN)
		return "<font size = 4>The Soviets may no longer cross!</font>"
	else
		return ""
/obj/map_metadata/forest/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (caribbean_blocking_area_types.Find(A.type))
		if (H.faction_text == faction1)
			return !faction1_can_cross_blocks()
		else if (H.faction_text == faction2)
			return !faction2_can_cross_blocks()
		else
			return FALSE
	return FALSE
/obj/map_metadata/forest/roundend_condition_def2name(define)
	..()
	switch (define)
		if (GERMAN)
			return "German"
		if (RUSSIAN)
			return "Soviet"
		if (CIVILIAN)
			return "UPA"
/obj/map_metadata/forest/roundend_condition_def2army(define)
	..()
	switch (define)
		if (GERMAN)
			return "Germans"
		if (RUSSIAN)
			return "Soviets"
		if (CIVILIAN)
			return "UPA"

/obj/map_metadata/forest/army2name(army)
	..()
	switch (army)
		if ("Germans")
			return "German"
		if ("Soviets")
			return "Soviet"
		if ("UPA")
			return "UPA"