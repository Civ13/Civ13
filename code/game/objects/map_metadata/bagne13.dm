
/obj/map_metadata/bagne13
	ID = MAP_BAGNE13
	title = "Bagne 13"
	no_winner ="The round is proceeding normally."
	lobby_icon = 'icons/lobby/bagne.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle, /area/caribbean/no_mans_land/invisible_wall/one)
	respawn_delay = 3600
	has_hunger = TRUE

	faction_organization = list(
		FRENCH,
		CIVILIAN)

	roundend_condition_sides = list(
		list(FRENCH) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/russian/land/inside/command,
		)
	age = "1933"
	ordinal_age = 6
	faction_distribution_coeffs = list(FRENCH = 0.25, CIVILIAN = 0.75)
	battle_name = "Bagne de L'Enfer Vert"
	mission_start_message = "<font size=4>The guards have <b>4 minutes</b> to prepare before the grace wall is removed for the Guards, the Prisoners won't be able to cross until 30 minutes have elapsed.<br>The <b>Guards</b> must keep the prisoners contained, and make them serve the French Republic with forced labor. The <b>Prisoners</b> must try to survive, work, and fulfill their personal objectives.</font>"
	faction1 = FRENCH
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"Red Army Choir - Slavery and Suffering:1" = 'sound/music/slavery_and_suffering.ogg')
	gamemode = "Prison Simulation"
	var/list/points = list(
		list("Guards",0,0),
	)
	is_RP = TRUE
	var/gracedown1 = TRUE
	var/siren = FALSE
	grace_wall_timer = 2400
/obj/map_metadata/bagne13/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/french))
		if (J.is_prison)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/civilian))
		if (J.title == "Cuistot" || J.title == "Infirmier" || J.title == "Bucheron")
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/bagne13/roundend_condition_def2name(define)
	..()
	switch (define)
		if (FRENCH)
			return "Guard"
		if (CIVILIAN)
			return "Prisoner"
/obj/map_metadata/bagne13/roundend_condition_def2army(define)
	..()
	switch (define)
		if (FRENCH)
			return "Guards"
		if (CIVILIAN)
			return "Prisoners"

/obj/map_metadata/bagne13/army2name(army)
	..()
	switch (army)
		if ("Guards")
			return "Guard"
		if ("Prisoners")
			return "Prisoner"


/obj/map_metadata/bagne13/cross_message(faction)
	if (faction == CIVILIAN)
		return ""
	else if (faction == FRENCH)
		return "<font size = 4>The grace wall is down!</font>"
	else
		return ""

/obj/map_metadata/bagne13/reverse_cross_message(faction)
	if (faction == CIVILIAN)
		return ""
	else if (faction == FRENCH)
		return "<font size = 4>The grace wall is up!</font>"
	else
		return ""
/obj/map_metadata/bagne13/New()
	..()
	spawn(100)
		load_new_recipes("config/crafting/material_recipes_camp.txt")
		override_global_recipes = "camp"
	spawn(3000)
		check_points_msg()
		config.no_respawn_delays = FALSE

/obj/map_metadata/bagne13/proc/check_points()
	for(var/i in points)
		if (i[1] != "Guards")
			i[2]=0
	for (var/mob/living/human/H in player_list)
		if (H.stat!=DEAD && H.original_job && istype(H.original_job, /datum/job/civilian/prisoner))
			var/curval = 0
			var/area/A = get_area(H)
			if (istype(A, /area/caribbean/nomads/ice/target))
				for(var/i in points)
					if (i[1]==H.nationality)
						i[3]+=4
					else if (i[1]!="Guards")
						i[3]+=2
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

/obj/map_metadata/bagne13/proc/check_points_msg()
	check_points()
	spawn(1)
		to_chat(world, "<font size = 4><span class = 'notice'><b>Current Score:</b></font></span>")
		for (var/i=1,i<=points.len,i++)
			to_chat(world, "<br><font size = 3><span class = 'notice'>[points[i][1]]: <b>[points[i][2]+points[i][3]]</b></span></font>")

	spawn(2400)
		check_points_msg()
	return

/obj/map_metadata/bagne13/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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

/obj/map_metadata/bagne13/proc/alarm_proc()
	if (siren)
		var/warning_sound = sound('sound/misc/siren.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		for (var/mob/M in player_list)
			M.client << warning_sound
		to_chat(world, "<font size=3 color='red'><center><b>ALARM</b><br>The alarm is still on!</center></font>")

		spawn(285)
			if (siren)
				alarm_proc()
			return


/obj/structure/camp_exportbook/bagne
	name = "camp exports"
	desc = "Use this to export products from the camp and gain points for the guards."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook2"
	density = TRUE
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/camp_exportbook/bagne/attackby(var/obj/item/stack/S, var/mob/living/human/H)
	var/obj/map_metadata/bagne13/G = null
	if (istype(map, /obj/map_metadata/bagne13))
		G = map
		if (istype(S, /obj/item/stack/material/wood))
			for(var/i in G.points)
				if (i[1]=="Guards")
					i[2]+=S.amount*S.value
					to_chat(H, "You export \the [S].")
					qdel(S)
					new/obj/item/stack/money/rubles(src.loc, round(S.amount*S.value))
					return
	else
		return