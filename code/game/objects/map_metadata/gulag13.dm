#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/gulag13
	ID = MAP_GULAG13
	title = "GULAG 13 (120x100x1)"
	lobby_icon_state = "ww2"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 600
	squad_spawn_locations = FALSE
	faction_organization = list(
		RUSSIAN,
		CIVILIAN)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/russian/land/inside/command,
		)
	age = "1946"
	ordinal_age = 6
	faction_distribution_coeffs = list(RUSSIAN = 0.2, CIVILIAN = 0.8)
	battle_name = "Gulag nr. 13"
	mission_start_message = "<font size=4>All factions have <b>4 minutes</b> to prepare before the grace wall is removed.<br>The <b>NKVD</b> must keep the prisoners contained, and make them serve the Soviet Union with forced labor. The <b>Prisoners</b> must try to survive, increase their faction power, and if possible, escape.</font>"
	faction1 = RUSSIAN
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_SNOW, WEATHER_BLIZZARD)
	songs = list(
		"The Great Escape:1" = 'sound/music/the_great_escape.ogg')
	gamemode = "Prison Simulation"
	var/list/points = list(
		list("Guards",0),
		list("Vory",0),
		list("Germans",0),
		list("Polish",0),
		list("Ukrainians",0),
	)

obj/map_metadata/gulag13/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian/fantasy))
		. = FALSE
	if (istype(J, /datum/job/russian))
		if (J.is_prison)
			. = TRUE
		else
			. = FALSE
	else
		if (J.is_prison && J.title != "DO NOT USE")
			. = TRUE
		else
			. = FALSE

/obj/map_metadata/gulag13/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 2400 || admin_ended_all_grace_periods)

/obj/map_metadata/gulag13/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 2400 || admin_ended_all_grace_periods)


/obj/map_metadata/gulag13/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "NKVD"
		if (CIVILIAN)
			return "Prisoner"
/obj/map_metadata/gulag13/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "NKVD Guards"
		if (CIVILIAN)
			return "Prisoners"

/obj/map_metadata/gulag13/army2name(army)
	..()
	switch (army)
		if ("NKVD Guards")
			return "NKVD"
		if ("Prisoners")
			return "Prisoner"


/obj/map_metadata/gulag13/cross_message(faction)
	if (faction == CIVILIAN)
		return ""
	else if (faction == RUSSIAN)
		return "<font size = 4>The grace wall is down!</font>"
	else
		return ""

/obj/map_metadata/gulag13/reverse_cross_message(faction)
	if (faction == CIVILIAN)
		return ""
	else if (faction == RUSSIAN)
		return "<font size = 4>The grace wall is up!</font>"
	else
		return ""
/obj/map_metadata/gulag13/New()
	..()
	spawn(3000)
		check_points_msg()

/obj/map_metadata/gulag13/proc/check_points_msg()
	spawn(1)
		world << "<font size = 4><span class = 'notice'><b>Current Score:</b></font></span>"
		for (var/i=1,i<=points.len,i++)
			world << "<br><font size = 3><span class = 'notice'>[points[i][1]]: <b>[points[i][2]]</b></span></font>"
	spawn(3000)
		check_points_msg()
	return

#undef NO_WINNER