/obj/map_metadata/forest
	ID = MAP_FOREST
	title = "Forest"
	lobby_icon_state = "ww2"
	no_winner ="The battle for the city is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/one, /area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 300


	faction_organization = list(
		GERMAN,
		RUSSIAN)

	roundend_condition_sides = list(
		list(GERMAN) = /area/caribbean/german/inside/objective,
		list(RUSSIAN) = /area/caribbean/russian/land/inside/command,
		)
	age = "1943"
	songs = list(
		"Neue Deutsche Welle (Remix):1" = 'sound/music/neue_deutsche_welle.ogg',)
	ordinal_age = 6
	faction_distribution_coeffs = list(GERMAN = 0.5, RUSSIAN = 0.5)
	battle_name = "Ukrainian Forest"
	mission_start_message = "<font size=4>The <b>Wehrmacht</b> and <b>Red Army</b> are facing each other in the forests of Ukraine! The russians may cross after 15 minutes! It will start in <b>7 minutes</b></font>"
	faction1 = GERMAN
	faction2 = RUSSIAN
	var/gracedown1 = TRUE

/obj/map_metadata/forest/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/german/tank_crew) || istype(J, /datum/job/russian/tank_crew))
		. = TRUE
	else if (J.is_ss_panzer == TRUE)
		. = FALSE
	else if (J.is_tanker == TRUE)
		. = FALSE
	else if (J.is_ww2 == TRUE && J.is_reichstag == FALSE)
		. = TRUE
	else if (J.is_reichstag == TRUE)
		. = FALSE
	else
		. = FALSE
/obj/map_metadata/forest/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 9000 || admin_ended_all_grace_periods)

/obj/map_metadata/forest/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4200 || admin_ended_all_grace_periods)

/obj/map_metadata/forest/cross_message(faction)
	if (faction == GERMAN)
		return "<font size = 4>The germans may cross!,</font>"
	else if (faction == RUSSIAN)
		return "<font size = 4>The soviets may cross!</font>"
	else
		return ""

/obj/map_metadata/forest/reverse_cross_message(faction)
	if (faction == GERMAN)
		return "<font size = 4>The germans may no longer cross!,</font>"
	else if (faction == RUSSIAN)
		return "<font size = 4>The soviets may no longer cross!</font>"
	else
		return ""
/obj/map_metadata/forest/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (caribbean_blocking_area_types.Find(A.type))
		if (A.name == "I grace wall")
			if (!gracedown1)
				if ((H.faction_text == faction1) && (processes.ticker.playtime_elapsed >= 4200))
					return TRUE
				else if ((H.faction_text == faction2) && (processes.ticker.playtime_elapsed >= 9000))
					return TRUE
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
/obj/map_metadata/forest/roundend_condition_def2army(define)
	..()
	switch (define)
		if (GERMAN)
			return "Germans"
		if (RUSSIAN)
			return "Soviets"

/obj/map_metadata/forest/army2name(army)
	..()
	switch (army)
		if ("Germans")
			return "German"
		if ("Soviets")
			return "Soviet"