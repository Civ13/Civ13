/obj/map_metadata/occupation
	ID = MAP_OCCUPATION
	title = "Occupation"
	no_winner ="The round is proceeding normally."
	lobby_icon = "icons/lobby/ww2.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/one, /area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 4000
	has_hunger = TRUE

	faction_organization = list(
		GERMAN,
		CIVILIAN)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/russian/land/inside/command,
		)
	age = "1942"
	ordinal_age = 6
	faction_distribution_coeffs = list(GERMAN = 0.35, CIVILIAN = 0.65)
	battle_name = "Occupation"
	mission_start_message = "<font size=4>All factions have 10 minutes to prepare before the SS can leave their base. <br> After 20 minutes civilians (including UPA) will be able to access the SS base and UPA armoury unlocks. <br> To gain points the <b>SS</b> must imprison (passive point generation) or kill (one time point gain) all the UPA partisans and any murderers hidden within the populace while still maintaining peace and order. <br> The <b>UPA</b> must rid the city of the Polish oppressors and kill enemy troops and officers(one time point gain).<br> Civilians earn points for their nationality by having rubles in their pockets (points = rubles in pockets).<br> <b>The faction with the most points wins!</b><br></font>"
	faction1 = CIVILIAN
	faction2 = GERMAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"The Great Escape:1" = "sound/music/the_great_escape.ogg")
	gamemode = "Occupation"
	var/list/points = list(
		list("SS",0,0),
		list("UPA",0,0),
		list("German",0,0),
		list("Polish",0,0),
		list("Ukrainian",0,0),
	)
	is_RP = TRUE
	var/gracedown1 = TRUE
/obj/map_metadata/occupation/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_occupation && istype(J, /datum/job/civilian/occupation) && J.title != "DONT USE")
		. = TRUE
	if (J.is_occupation && J.is_upa)
		. = TRUE
	if (istype(J, /datum/job/civilian/fantasy))
		. = FALSE
	if (J.is_civil_war)
		. = FALSE
	if (J.is_abashiri)
		. = FALSE
	if (istype(J, /datum/job/german))
		if (J.is_occupation)
			. = TRUE
		else
			. = FALSE
/obj/map_metadata/occupation/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 12000 || admin_ended_all_grace_periods)

/obj/map_metadata/occupation/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 6000 || admin_ended_all_grace_periods)

/obj/map_metadata/occupation/roundend_condition_def2name(define)
	..()
	switch (define)
		if (GERMAN)
			return "SS"
		if (CIVILIAN)
			return "Civilian"
/obj/map_metadata/occupation/roundend_condition_def2army(define)
	..()
	switch (define)
		if (GERMAN)
			return "SS Occupiers"
		if (CIVILIAN)
			return "Civilians"

/obj/map_metadata/occupation/army2name(army)
	..()
	switch (army)
		if ("SS Occupiers")
			return "SS"
		if ("Civilians")
			return "Civilian"


/obj/map_metadata/occupation/cross_message(faction)
	if (faction == CIVILIAN)
		return ""
	else if (faction == GERMAN)
		return "<font size = 4>The grace wall is down!</font>"
	else
		return ""

/obj/map_metadata/occupation/reverse_cross_message(faction)
	if (faction == CIVILIAN)
		return ""
	else if (faction == GERMAN)
		return "<font size = 4>The grace wall is up!</font>"
	else
		return ""

/obj/map_metadata/occupation/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (caribbean_blocking_area_types.Find(A.type))
		if (H.faction_text == faction2 || H.faction_text == faction1 && !H.original_job.is_upa)
			return !faction1_can_cross_blocks()
		else if (H.original_job.is_upa)
			return !faction2_can_cross_blocks()
		else
			return FALSE
	return FALSE

/obj/map_metadata/occupation/New()
	..()
	var/newnamee = list("UPA" = list(175,175,175,null,0,"star","#FF0000","#000000",0,0))
	var/newnamef = list("SS" = list(175,175,175,null,0,"cross","#000000","#FFFFFF",0,0))
	custom_civs += newnamee
	custom_civs += newnamef
	spawn(2600)
		check_points_msg()
		config.no_respawn_delays = FALSE
/obj/map_metadata/occupation/proc/check_points()
/*	for(var/i in points)
		if (i[1] != "SS")
			i[2]=0*/
	for (var/mob/living/human/H in player_list)
		if (H.stat!=DEAD && H.faction_text == CIVILIAN)
			var/curval = 0
			if (H.stat!=DEAD && H.original_job.is_upa == TRUE)
				var/area/A = get_area(H)
				if (istype(A, /area/caribbean/german/inside/objective))
					if (H.stat!=DEAD && H.original_job.is_upa == TRUE && H.original_job.is_squad_leader == TRUE)
						for(var/i in points)
							if (i[1]=="SS")
								i[2]+= 150
					else if (H.stat!=DEAD && H.original_job.is_upa == TRUE && (H.original_job.is_officer == TRUE && !H.original_job.is_squad_leader == TRUE))
						for(var/i in points)
							if (i[1]=="SS")
								i[2]+= 250
					else
						for(var/i in points)
							if (i[1]=="SS")
								i[2]+= 75
			for(var/obj/item/stack/money/rubles/R in H)
				curval += R.amount
			if (H.wear_suit && istype(H.wear_suit, /obj/item/clothing/suit/storage))
				var/obj/item/clothing/suit/storage/ST = H.wear_suit
				for(var/obj/item/stack/money/rubles/R in ST.pockets)
					curval += R.amount
			for(var/i in points)
				if (i[1]==H.nationality)
					i[2]+=curval
	return

/obj/map_metadata/occupation/proc/check_points_msg()
	check_points()
	spawn(1)
		world << "<font size = 4><span class = 'notice'><b>Current Score:</b></font></span>"
		for (var/i=1,i<=points.len,i++)
			world << "<br><font size = 3><span class = 'notice'>[points[i][1]]: <b>[points[i][2]+points[i][3]]</b></span></font>"

	spawn(2400)
		check_points_msg()
	return
