/obj/map_metadata/abashiri
	ID = MAP_ABASHIRI
	title = "Abashiri Prison"
	no_winner ="The round is proceeding normally."
	lobby_icon = "icons/lobby/abashiri.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 3600
	has_hunger = TRUE

	faction_organization = list(
		JAPANESE,
		CIVILIAN)

	roundend_condition_sides = list(
		list(JAPANESE) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/russian/land/inside/command,
		)
	age = "1905"
	ordinal_age = 4
	faction_distribution_coeffs = list(JAPANESE = 0.25, CIVILIAN = 0.75)
	battle_name = "Abashiri Prison"
	mission_start_message = "<font size=4>The <b>Abashiri Guards</b> have to let the POW's out and escort them to their routines under supervision.<br>The <b>Guards</b> must keep the prisoners contained, and make them serve the Prison with Manual Labor. The <b>Prisoners</b> must try to survive, increase their faction power, and if possible, escape.</font>"
	faction1 = JAPANESE
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"The Great Escape:1" = "sound/music/the_great_escape.ogg")
	gamemode = "Prison Simulation"
	var/list/points = list(
		list("Guards",0,0),
		list("Russian",0,0),
		list("Japanese",0,0),
		list("Ainu",0,0),
	)
	is_RP = TRUE
	var/gracedown1 = TRUE
	var/siren = FALSE
/obj/map_metadata/abashiri/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian/fantasy))
		. = FALSE
	if (J.is_civil_war == TRUE)
		. = FALSE
	if (istype(J, /datum/job/japanese/abashiri))
		if (J.is_abashiri)
			. = TRUE
		else
			. = FALSE
	else
		if (J.is_abashiri && J.title != "DO NOT USE")
			. = TRUE
		else
			. = FALSE

/obj/map_metadata/abashiri/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 12000 || admin_ended_all_grace_periods)

/obj/map_metadata/abashiri/roundend_condition_def2name(define)
	..()
	switch (define)
		if (JAPANESE)
			return "Abashiri"
		if (CIVILIAN)
			return "Prisoner"
/obj/map_metadata/abashiri/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Abashiri Guards"
		if (CIVILIAN)
			return "Prisoners"

/obj/map_metadata/abashiri/army2name(army)
	..()
	switch (army)
		if ("Abashiri Guards")
			return "Abashiri"
		if ("Prisoners")
			return "Prisoner"


/obj/map_metadata/abashiri/cross_message(faction)
	if (faction == CIVILIAN)
		return ""
	else if (faction == JAPANESE)
		return "<font size = 4>The prison is now escapable!</font>"
	else
		return ""

/obj/map_metadata/abashiri/reverse_cross_message(faction)
	if (faction == CIVILIAN)
		return ""
	else if (faction == JAPANESE)
		return "<font size = 4>The prison is now escapable!</font>"
	else
		return ""
/obj/map_metadata/abashiri/New()
	..()
	spawn(100)
		load_new_recipes("config/crafting/material_recipes_abashiri.txt")
		override_global_recipes = "abashiri"
	spawn(3000)
		check_points_msg()
		config.no_respawn_delays = FALSE

/obj/map_metadata/abashiri/proc/check_points()
	for(var/i in points)
		if (i[1] != "Guards")
			i[2]=0
	for (var/mob/living/human/H in player_list)
		if (H.stat!=DEAD && H.original_job && istype(H.original_job, /datum/job/civilian/abashiri/prisoner))
			var/curval = 0
			var/area/A = get_area(H)
			if (istype(A, /area/caribbean/nomads/ice/target))
				for(var/i in points)
					if (i[1]==H.nationality)
						i[3]+=4
					else if (i[1]!="Guards")
						i[3]+=2
			for(var/obj/item/stack/money/yen/R in H)
				curval += R.amount
			if (H.wear_suit && istype(H.wear_suit, /obj/item/clothing/suit/storage))
				var/obj/item/clothing/suit/storage/ST = H.wear_suit
				for(var/obj/item/stack/money/yen/R in ST.pockets)
					curval += R.amount
			for(var/i in points)
				if (i[1]==H.nationality)
					i[2]+=curval
	return

/obj/map_metadata/abashiri/proc/check_points_msg()
	check_points()
	spawn(1)
		world << "<font size = 4><span class = 'notice'><b>Current Score:</b></font></span>"
		for (var/i=1,i<=points.len,i++)
			world << "<br><font size = 3><span class = 'notice'>[points[i][1]]: <b>[points[i][2]+points[i][3]]</b></span></font>"
		var/donecheck = FALSE
		for(var/mob/living/human/H in player_list)
			if(H.stat!=DEAD && H.original_job && istype(H.original_job, /datum/job/civilian/abashiri/prisoner) && !donecheck)
				var/area/A = get_area(H)
				if (istype(A, /area/caribbean/nomads/ice/target))
					world << "<br><font size = 3><span class = 'warning'>There are prisoners currently escaping!</span></font>"
					donecheck = TRUE

	spawn(2400)
		check_points_msg()
	return

/obj/map_metadata/abashiri/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (caribbean_blocking_area_types.Find(A.type))
		if (A.name == "I grace wall")
			if (!gracedown1)
				return TRUE
			else
				return FALSE
		else
			return (!faction1_can_cross_blocks() || !faction2_can_cross_blocks())
	return FALSE

/obj/map_metadata/abashiri/proc/alarm_proc()
	if (siren)
		var/warning_sound = sound('sound/misc/siren.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		for (var/mob/M in player_list)
			M.client << warning_sound
		world << "<font size=3 color='red'><center><b>ALARM</b><br>The alarm is still on!</center></font>"

		spawn(285)
			if (siren)
				alarm_proc()
			return