
/obj/map_metadata/vadso_city
	ID = MAP_VADSO_CITY
	title = "Vadso City"
	lobby_icon = "icons/lobby/operation_falcon.png"
	no_winner = "The battle for the city is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/sea,/area/caribbean/no_mans_land/invisible_wall/taiga,/area/caribbean/no_mans_land/invisible_wall/taiga/one,/area/caribbean/no_mans_land/invisible_wall/taiga/two)
	respawn_delay = 600

	faction_organization = list(
		BRITISH,
		RUSSIAN)

	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/german/reichstag/roof/objective,
		list(RUSSIAN) = /area/caribbean/german/reichstag/roof/objective,
		)
	age = "2017"
	ordinal_age = 8
	faction_distribution_coeffs = list(BRITISH = 0.5, RUSSIAN = 0.5)
	battle_name = "Vadso City"
	mission_start_message = "<font size=4>Both factions have <b>3 minutes</b> to prepare before the ceasefire ends!</font> <br><big>Points are added to each team for each minute they control the different objectives.</big> <br><font size=6>First team to reach <b>100</b> points wins!</big></font>"
	faction1 = BRITISH
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"Doe Maar - The Bomb (De Bom):1" = "sound/music/de_bom.ogg",)
	gamemode = "Area Control"
	ambience = list('sound/ambience/battle1.ogg')
	var/rus_points = 0
	var/british_points = 0
	var/win_points = 100 // Amount of points needed to win

	var/faction1_flag = "british"
	var/faction2_flag = "russian"

	var/a1_control = "nobody"
	var/a1_name = "Radar Station"

	var/a2_control = "nobody"
	var/a2_name = "Western City"

	var/a3_control = "nobody"
	var/a3_name = "Eastern City"

	var/a4_control = "nobody"
	var/a4_name = "Farm"

	var/a5_control = "nobody"
	var/a5_name = "Hydro Dam"
	grace_wall_timer = 3 MINUTES
	no_hardcore = TRUE
	fob_spawns = TRUE

/obj/map_metadata/vadso_city/New()
	..()
	spawn(3000)
		points_check()

/obj/map_metadata/vadso_city/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_operation_falcon == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/vadso_city/roundend_condition_def2name(define)
	..()
	switch (define)
		if (BRITISH)
			return "British"
		if (RUSSIAN)
			return "Russian"
/obj/map_metadata/vadso_city/roundend_condition_def2army(define)
	..()
	switch (define)
		if (BRITISH)
			return "British Armed Forces"
		if (RUSSIAN)
			return "Russian Armed Forces"

/obj/map_metadata/vadso_city/army2name(army)
	..()
	switch (army)
		if ("British Armed Forces")
			return "British"
		if ("Russian Armed Forces")
			return "Russian"


/obj/map_metadata/vadso_city/cross_message(faction)
	var/warning_sound = sound('sound/effects/siren_once.ogg', repeat = FALSE, wait = TRUE, channel = 777)
	for (var/mob/M in player_list)
		M.client << warning_sound

	if (faction == BRITISH)
		return "<font size = 4>The battle of Vadso City has begun!</font>"
	else if (faction == RUSSIAN)
		return "<font size = 4>The battle of Vadso City has begun!</font>"
	else
		return ""

/obj/map_metadata/vadso_city/proc/points_check()
	if (processes.ticker.playtime_elapsed > 3000)
		var/c1 = 0
		var/c2 = 0
		var/cust_color = "white"
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/one))
				if (H.faction_text == BRITISH && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == RUSSIAN && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a1_control = "none"
			cust_color = "white"
		else if (c1 > c2)
			a1_control = "British Armed Forces"
			cust_color = "blue"
		else if (c2 > c1)
			a1_control = "Russian Armed Forces"
			cust_color = "red"
		if (a1_control != "none")
			if (a1_control == "Russian Armed Forces")
				cust_color = "red"
				rus_points++
			else if (a1_control == "British Armed Forces")
				cust_color = "blue"
				british_points++
			else
				cust_color = "white"
			world << "<big><b>[a1_name]</b>: <font color='[cust_color]'>[a1_control]</font></big>"
		else
			world << "<big><b>[a1_name]</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/two))
				if (H.faction_text == BRITISH && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == RUSSIAN && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a2_control = "none"
			cust_color = "white"
		else if (c1 > c2)
			a2_control = "British Armed Forces"
			cust_color = "blue"
		else if (c2 > c1)
			a2_control = "Russian Armed Forces"
			cust_color = "red"
		if (a2_control != "none")
			if (a2_control == "Russian Armed Forces")
				cust_color = "red"
				rus_points++
			else if (a2_control == "British Armed Forces")
				cust_color = "blue"
				british_points++
			else
				cust_color = "white"
			world << "<big><b>[a2_name]</b>: <font color='[cust_color]'>[a2_control]</font></big>"
		else
			world << "<big><b>[a2_name]</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/three))
				if (H.faction_text == BRITISH && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == RUSSIAN && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a3_control = "none"
			cust_color = "white"
		else if (c1 > c2)
			a3_control = "British Armed Forces"
			cust_color = "blue"
		else if (c2 > c1)
			a3_control = "Russian Armed Forces"
			cust_color = "red"
		if (a3_control != "none")
			if (a3_control == "Russian Armed Forces")
				cust_color = "red"
				rus_points++
			else if (a3_control == "British Armed Forces")
				cust_color = "blue"
				british_points++
			else
				cust_color = "white"
			world << "<big><b>[a3_name]</b>: <font color='[cust_color]'>[a3_control]</font></big>"
		else
			world << "<big><b>[a3_name]</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/four))
				if (H.faction_text == BRITISH && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == RUSSIAN && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a4_control = "none"
			cust_color = "white"
		else if (c1 > c2)
			a4_control = "British Armed Forces"
			cust_color = "blue"
		else if (c2 > c1)
			a4_control = "Russian Armed Forces"
			cust_color = "red"
		if (a4_control != "none")
			if (a4_control == "Russian Armed Forces")
				cust_color = "red"
				rus_points++
			else if (a4_control == "British Armed Forces")
				cust_color = "blue"
				british_points++
			else
				cust_color = "white"
			world << "<big><b>[a4_name]</b>: <font color='[cust_color]'>[a4_control]</font></big>"
		else
			world << "<big><b>[a4_name]</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/five))
				if (H.faction_text == BRITISH && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == RUSSIAN && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a4_control = "none"
			cust_color = "white"
		else if (c1 > c2)
			a4_control = "British Armed Forces"
			cust_color = "blue"
		else if (c2 > c1)
			a4_control = "Russian Armed Forces"
			cust_color = "red"
		if (a4_control != "none")
			if (a4_control == "Russian Armed Forces")
				cust_color = "red"
				rus_points++
			else if (a4_control == "British Armed Forces")
				cust_color = "blue"
				british_points++
			else
				cust_color = "white"
			world << "<big><b>[a5_name]</b>: <font color='[cust_color]'>[a4_control]</font></big>"
		else
			world << "<big><b>[a5_name]</b>: Nobody</big>"
	spawn(600)
		points_check()
		spawn(5)
			world << "<big><b>Current Points:</big></b>"
			world << "<big>British: [british_points]</big>"
			world << "<big>Russian: [rus_points]</big>"
	
	switch (a1_control)
		if ("British Armed Forces")
			faction1_supply_points += 20
			for (var/obj/structure/flag/objective/one/F in world)
				F.icon_state = "[faction1_flag]"
		if ("Russian Armed Forces")
			faction2_supply_points += 20
			for (var/obj/structure/flag/objective/one/F in world)
				F.icon_state = "[faction2_flag]"
		else
			for (var/obj/structure/flag/objective/one/F in world)
				F.icon_state = "white"
	switch (a2_control)
		if ("British Armed Forces")
			faction1_supply_points += 20
			for (var/obj/structure/flag/objective/two/F in world)
				F.icon_state = "[faction1_flag]"
		if ("Russian Armed Forces")
			faction2_supply_points += 20
			for (var/obj/structure/flag/objective/two/F in world)
				F.icon_state = "[faction2_flag]"
		else
			for (var/obj/structure/flag/objective/two/F in world)
				F.icon_state = "white"
	switch (a3_control)
		if ("British Armed Forces")
			faction1_supply_points += 20
			for (var/obj/structure/flag/objective/three/F in world)
				F.icon_state = "[faction1_flag]"
		if ("Russian Armed Forces")
			faction2_supply_points += 20
			for (var/obj/structure/flag/objective/three/F in world)
				F.icon_state = "[faction2_flag]"
		else
			for (var/obj/structure/flag/objective/three/F in world)
				F.icon_state = "white"
	switch (a4_control)
		if ("British Armed Forces")
			faction1_supply_points += 20
			for (var/obj/structure/flag/objective/four/F in world)
				F.icon_state = "[faction1_flag]"
		if ("Russian Armed Forces")
			faction2_supply_points += 20
			for (var/obj/structure/flag/objective/four/F in world)
				F.icon_state = "[faction2_flag]"
		else
			for (var/obj/structure/flag/objective/four/F in world)
				F.icon_state = "white"
	switch (a5_control)
		if ("British Armed Forces")
			faction1_supply_points += 20
			for (var/obj/structure/flag/objective/five/F in world)
				F.icon_state = "[faction1_flag]"
		if ("Russian Armed Forces")
			faction2_supply_points += 20
			for (var/obj/structure/flag/objective/five/F in world)
				F.icon_state = "[faction2_flag]"
		else
			for (var/obj/structure/flag/objective/five/F in world)
				F.icon_state = "white"

/obj/map_metadata/vadso_city/update_win_condition()
	if (processes.ticker.playtime_elapsed > 3000)
		if (rus_points < win_points && british_points < win_points)
			return TRUE
		if (rus_points >= win_points && rus_points > british_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Russians</b> have reached [rus_points] points and claimed victory in Operation Falcon!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
		if (british_points >= win_points && british_points > rus_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>British</b> have reached [british_points] points and claimed victory in Operation Falcon!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
	return TRUE

/obj/map_metadata/vadso_city/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall) || istype(A, /area/caribbean/no_mans_land/invisible_wall/sea))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

