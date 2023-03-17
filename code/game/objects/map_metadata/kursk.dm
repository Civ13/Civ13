
/obj/map_metadata/kursk
	ID = MAP_KURSK
	title = "Kursk"
	lobby_icon = "icons/lobby/kursk.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/temperate)
	respawn_delay = 1200

	faction_organization = list(
		GERMAN,
		RUSSIAN)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/russian/,
		list(GERMAN) = /area/caribbean/german/,
		)
	age = "1943"
	ordinal_age = 6
	faction_distribution_coeffs = list(GERMAN = 0.5, RUSSIAN = 0.5)
	battle_name = "battle of Kursk"
	mission_start_message = "<font size=4>All factions have <b>6 minutes</b> to prepare before the ceasefire ends!<br></font>"
	faction1 = GERMAN
	faction2 = RUSSIAN
	grace_wall_timer = 3600
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Red Army Choir - Katyusha:1" = "sound/music/katyusha.ogg",)

/obj/map_metadata/kursk/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_ww2 == TRUE && J.is_tanker == TRUE)
		. = TRUE
	else if (J.is_ss_panzer == TRUE)
		. = TRUE
	else if (istype(J, /datum/job/german/mediziner) || istype(J, /datum/job/russian/doctor_soviet))
		. = TRUE
	else if (istype(J, /datum/job/russian/sniper_soviet))
		. = TRUE
	else if (istype(J, /datum/job/russian/antitank_soldier_soviet) || istype(J, /datum/job/russian/antitank_assistant_soldier_soviet))
		. = TRUE
	else if (istype(J, /datum/job/german/german_antitank) || istype(J, /datum/job/german/german_antitankassitant))
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/kursk/roundend_condition_def2name(define)
	..()
	switch (define)
		if (GERMAN)
			return "German"
		if (RUSSIAN)
			return "Soviet"
/obj/map_metadata/kursk/roundend_condition_def2army(define)
	..()
	switch (define)
		if (GERMAN)
			return "Germans"
		if (RUSSIAN)
			return "Soviets"

/obj/map_metadata/kursk/army2name(army)
	..()
	switch (army)
		if ("Germans")
			return "German"
		if ("Soviets")
			return "Soviet"

/obj/map_metadata/kursk/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The Soviets may now cross the invisible wall!</font>"
	else if (faction == GERMAN)
		return "<font size = 4>The Germans may now cross the invisible wall!</font>"

/obj/map_metadata/kursk/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Soviets may no longer cross the invisible wall!</span>"
	else if (faction == GERMAN)
		return "<span class = 'userdanger'>The Germans may no longer cross the invisible wall!</span>"

