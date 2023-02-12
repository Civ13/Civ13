
/obj/map_metadata/khalkhyn
	ID = MAP_KHALKHYN_GOL
	title = "Khalkhyn Gol"
	lobby_icon = "icons/lobby/ww2.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 1200

	faction_organization = list(
		JAPANESE,
		RUSSIAN)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/russian/land/inside/command,
		list(JAPANESE) = /area/caribbean/japanese/land/inside/command,
		)
	age = "1939"
	ordinal_age = 6
	faction_distribution_coeffs = list(JAPANESE = 0.6, RUSSIAN = 0.4)
	battle_name = "battle of Khalkhyn Gol"
	mission_start_message = "<font size=4>All factions have <b>8 minutes</b> to prepare before the ceasefire ends!<br>The Japanese will win if they capture the <b>Soviet command</b>. The Soviets will win if they manage to capture the <b>Japanese command</b>.</font>"
	mosinonly = TRUE
	faction1 = JAPANESE
	faction2 = RUSSIAN
	grace_wall_timer = 4800
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Mugi to Heitai:1" = "sound/music/mugi_to_heitai.ogg",)

/obj/map_metadata/khalkhyn/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/russian/tank_crew) || istype(J, /datum/job/japanese/ija_ww2ATunit))
		. = TRUE
	else if (J.is_navy == TRUE || J.is_yakuza || J.is_tanker == TRUE || J.is_prison == TRUE || J.is_ss_panzer == TRUE || J.is_pacific == TRUE)
		. = FALSE
	else if (J.is_ww2 == TRUE && !J.is_sovaprif == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/khalkhyn/roundend_condition_def2name(define)
	..()
	switch (define)
		if (JAPANESE)
			return "Japanese"
		if (RUSSIAN)
			return "Soviet"
/obj/map_metadata/khalkhyn/roundend_condition_def2army(define)
	..()
	switch (define)
		if (JAPANESE)
			return "Japanese"
		if (RUSSIAN)
			return "Soviets"

/obj/map_metadata/khalkhyn/army2name(army)
	..()
	switch (army)
		if ("Japanese")
			return "Japanese"
		if ("Soviets")
			return "Soviet"


/obj/map_metadata/khalkhyn/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The Soviets may now cross the invisible wall!</font>"
	else if (faction == JAPANESE)
		return "<font size = 4>The Japanese may now cross the invisible wall!</font>"

/obj/map_metadata/khalkhyn/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Soviets may no longer cross the invisible wall!</span>"
	else if (faction == JAPANESE)
		return "<span class = 'userdanger'>The Japanese may no longer cross the invisible wall!</span>"

