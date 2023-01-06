
/obj/map_metadata/operation_falcon
	ID = MAP_OPERATION_FACLON
	title = "Operation Falcon"
	lobby_icon = "icons/lobby/operation_falcon.png"
	no_winner = "The battle for the city is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 600

	faction_organization = list(
		DUTCH,
		RUSSIAN)

	roundend_condition_sides = list(
		list(DUTCH) = /area/caribbean/german/reichstag/roof/objective,
		list(RUSSIAN) = /area/caribbean/german/reichstag/roof/objective,
		)
	age = "2026"
	ordinal_age = 8
	faction_distribution_coeffs = list(DUTCH = 0.5, RUSSIAN = 0.5)
	battle_name = "Operation Falcon"
	mission_start_message = "<font size=4>Both factions have <b>5 minutes</b> to prepare before the ceasefire ends!</font><br><big>Points are added to each team for each minute they control the <b>Radio Post, Eastern Suburbs, Factory and Lumber Company</b>.<br>First team to reach <b>100</b> points wins!</font>"
	faction1 = DUTCH
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"Doe Maar - The Bomb (De Bom):1" = "sound/music/de_bom.ogg",)
	gamemode = "Area Control"
	ambience = list('sound/ambience/battle1.ogg')
	var/rus_points = 0
	var/dutch_points = 0
	var/win_points = 100 // Amount of points needed to win
	var/a1_control = "nobody"
	var/a1_name = "Radio Post"

	var/a2_control = "nobody"
	var/a2_name = "Eastern Suburbs"

	var/a3_control = "nobody"
	var/a3_name = "Factory"

	var/a4_control = "nobody"
	var/a4_name = "Lumber Company"
	grace_wall_timer = 3000

/obj/map_metadata/operation_falcon/New()
	..()
	spawn(3000)
		points_check()

/obj/map_metadata/operation_falcon/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_operation_falcon == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/operation_falcon/roundend_condition_def2name(define)
	..()
	switch (define)
		if (DUTCH)
			return "Dutch"
		if (RUSSIAN)
			return "Russian"
/obj/map_metadata/operation_falcon/roundend_condition_def2army(define)
	..()
	switch (define)
		if (DUTCH)
			return "Dutch Royal Army"
		if (RUSSIAN)
			return "Russian Armed Forces"

/obj/map_metadata/operation_falcon/army2name(army)
	..()
	switch (army)
		if ("Dutch Royal Army")
			return "Dutch"
		if ("Russian Armed Forces")
			return "Russian"


/obj/map_metadata/operation_falcon/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>Operation Falcon has begun!</font>"
	else if (faction == DUTCH)
		return ""
	else
		return ""

/obj/map_metadata/operation_falcon/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>Both teams may no longer cross the invisible wall!</span>"
	else if (faction == DUTCH)
		return ""
	else
		return ""

/obj/map_metadata/operation_falcon/proc/points_check()
	if (processes.ticker.playtime_elapsed > 3000)
		var/c1 = 0
		var/c2 = 0
		var/cust_color = "white"
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/one))
				if (H.faction_text == "DUTCH" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a1_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a1_control = "Dutch Royal Army"
			cust_color="black"
		else if (c2 > c1)
			a1_control = "Russian Armed Forces"
			cust_color="red"
		if (a1_control != "none")
			if (a1_control == "Russian Armed Forces")
				cust_color = "red"
				rus_points++
			else if (a1_control == "Dutch Royal Army")
				cust_color = "black"
				dutch_points++
			else
				cust_color = "white"
			world << "<big><font color='[cust_color]'><b>[a1_name]</b>: [a1_control]</font></big>"
		else
			world << "<big><b>[a1_name]</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/two))
				if (H.faction_text == "DUTCH" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a2_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a2_control = "Dutch Royal Army"
			cust_color="black"
		else if (c2 > c1)
			a2_control = "Russian Armed Forces"
			cust_color="red"
		if (a2_control != "none")
			if (a2_control == "Russian Armed Forces")
				cust_color = "red"
				rus_points++
			else if (a2_control == "Dutch Royal Army")
				cust_color = "black"
				dutch_points++
			else
				cust_color = "white"
			world << "<big><font color='[cust_color]'><b>[a2_name]</b>: [a2_control]</font></big>"
		else
			world << "<big><b>[a2_name]</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/three))
				if (H.faction_text == "DUTCH" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a3_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a3_control = "Dutch Royal Army"
			cust_color="black"
		else if (c2 > c1)
			a3_control = "Russian Armed Forces"
			cust_color="red"
		if (a3_control != "none")
			if (a3_control == "Russian Armed Forces")
				cust_color = "red"
				rus_points++
			else if (a3_control == "Dutch Royal Army")
				cust_color = "black"
				dutch_points++
			else
				cust_color = "white"
			world << "<big><font color='[cust_color]'><b>[a3_name]</b>: [a3_control]</font></big>"
		else
			world << "<big><b>[a3_name]</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/four))
				if (H.faction_text == "DUTCH" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a4_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a4_control = "Dutch Royal Army"
			cust_color="black"
		else if (c2 > c1)
			a4_control = "Russian Armed Forces"
			cust_color="red"
		if (a4_control != "none")
			if (a4_control == "Russian Armed Forces")
				cust_color = "red"
				rus_points++
			else if (a4_control == "Dutch Royal Army")
				cust_color = "black"
				dutch_points++
			else
				cust_color = "white"
			world << "<big><font color='[cust_color]'><b>[a4_name]</b>: [a4_control]</font></big>"
		else
			world << "<big><b>[a4_name]</b>: Nobody</big>"
	spawn(600)
		points_check()
		spawn(300)
			world << "<big><b>Current Points:</big></b>"
			world << "<big>Dutch: [dutch_points]</big>"
			world << "<big>Russian: [rus_points]</big>"

/obj/map_metadata/operation_falcon/update_win_condition()
	if (processes.ticker.playtime_elapsed > 3000)
		if (rus_points < win_points && dutch_points < win_points)
			return TRUE
		if (rus_points >= win_points && rus_points > dutch_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Russians</b> have reached [rus_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
		if (dutch_points >= win_points && dutch_points > rus_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Dutch</b> have reached [dutch_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
	return TRUE

/obj/map_metadata/operation_falcon/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE
