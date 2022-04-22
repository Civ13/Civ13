
/obj/map_metadata/stalingrad
	ID = MAP_STALINGRAD
	title = "Stalingrad"
	lobby_icon_state = "stalingrad"
	no_winner ="The battle for the city is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/taiga,/area/caribbean/no_mans_land/invisible_wall/taiga/one,/area/caribbean/no_mans_land/invisible_wall/taiga/two)
	respawn_delay = 0

	faction_organization = list(
		GERMAN,
		RUSSIAN)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/german/reichstag/roof/objective,
		list(GERMAN) = /area/caribbean/german/reichstag/roof/objective,
		)
	age = "1942"
	ordinal_age = 6
	faction_distribution_coeffs = list(GERMAN = 0.5, RUSSIAN = 0.5)
	battle_name = "battle of Stalingrad"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!</font><br><big>Points are added to each team for each minute they control the <b>Train Station, Telephone Central and City Hall</b>.<br>First team to reach <b>40</b> points wins!</font>"
	faction1 = GERMAN
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"Red Army Choir - Katyusha:1" = "sound/music/katyusha.ogg",)
	gamemode = "Area Control"
	var/sov_points = 0
	var/ger_points = 0
	var/a1_control = "none"
	var/a2_control = "none"
	var/a3_control = "none"
	var/a4_control = "none"
/obj/map_metadata/stalingrad/New()
	..()
	spawn(3000)
		points_check()

/obj/map_metadata/stalingrad/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/german/tank_crew) || istype(J, /datum/job/russian/tank_crew))
		. = TRUE
	else if (J.is_ss_panzer == TRUE)
		. = FALSE
	else if (J.is_occupation == TRUE)
		. = FALSE
	else if (J.is_tanker == TRUE)
		. = FALSE
	else if (J.is_ww2 == TRUE && J.is_reichstag == FALSE)
		. = TRUE
	else if (J.is_reichstag == TRUE)
		. = FALSE
	else
		. = FALSE

/obj/map_metadata/stalingrad/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/stalingrad/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


/obj/map_metadata/stalingrad/roundend_condition_def2name(define)
	..()
	switch (define)
		if (GERMAN)
			return "German"
		if (RUSSIAN)
			return "Soviet"
/obj/map_metadata/stalingrad/roundend_condition_def2army(define)
	..()
	switch (define)
		if (GERMAN)
			return "Germans"
		if (RUSSIAN)
			return "Soviets"

/obj/map_metadata/stalingrad/army2name(army)
	..()
	switch (army)
		if ("Germans")
			return "German"
		if ("Soviets")
			return "Soviet"


/obj/map_metadata/stalingrad/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>Both teams may now cross the invisible wall!</font>"
	else if (faction == GERMAN)
		return ""
	else
		return ""

/obj/map_metadata/stalingrad/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>Both teams may no longer cross the invisible wall!</span>"
	else if (faction == GERMAN)
		return ""
	else
		return ""

/obj/map_metadata/stalingrad/proc/points_check()
	var/cust_color = "white"
	if (processes.ticker.playtime_elapsed > 6000)
		var/c1 = 0
		var/c2 = 0
		var/prev_control = a1_control
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/one))
				if (H.faction_text == "GERMAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a1_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a1_control = "Germans"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a1_control = "Soviets"
			cust_color="red"
			sov_points++
		if (a1_control != prev_control)
			if (prev_control != "none")
				world << "<big><font color='[cust_color]'>[prev_control]</font> lost the <b>Telephone Central</b>!</big>"
			else
				world << "<big><font color='[cust_color]'>[a1_control]</font> captured the <b>Telephone Central</b>!</big>"
		c1 = 0
		c2 = 0
		prev_control = a2_control
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/two))
				if (H.faction_text == "GERMAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a2_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a2_control = "Germans"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a2_control = "Soviets"
			cust_color="red"
			sov_points++
		if (a2_control != prev_control)
			if (prev_control != "none")
				world << "<big><font color='[cust_color]'>[prev_control]</font> lost the <b>Train Station</b>!</big>"
			else
				world << "<big><font color='[cust_color]'>[a2_control]</font> captured the <b>Train Station</b>!</big>"
		c1 = 0
		c2 = 0
		prev_control = a3_control
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/three))
				if (H.faction_text == "GERMAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a3_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a3_control = "Germans"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a3_control = "Soviets"
			cust_color="red"
			sov_points++
		if (a3_control != prev_control)
			if (prev_control != "none")
				world << "<big><font color='[cust_color]'>[prev_control]</font> lost the <b>City Hall</b>!</big>"
			else
				world << "<big><font color='[cust_color]'>[a3_control]</font> captured the <b>City Hall</b>!</big>"
	if (a1_control == "Soviets")
		cust_color = "red"
	else
		cust_color = "blue"
	world << "<big><font color='[cust_color]'><b>Telephone Central</b>: [a1_control]</font></big>"
	if (a2_control == "Soviets")
		cust_color = "red"
	else
		cust_color = "blue"
	world << "<big><font color='[cust_color]'><b>Train Station</b>: [a2_control]</font></big>"
	if (a3_control == "Soviets")
		cust_color = "red"
	else
		cust_color = "blue"
	world << "<big><font color='[cust_color]'><b>City Hall</b>: [a3_control]</font></big>"
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Germans: [ger_points]</big>"
	world << "<big>Soviets: [sov_points]</big>"
	spawn(300)
		points_check()

/obj/map_metadata/stalingrad/update_win_condition()
	if (processes.ticker.playtime_elapsed > 6000)
		if (sov_points < 40 && ger_points < 40)
			return TRUE
		if (sov_points >= 40 && sov_points > ger_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Soviets</b> have reached [sov_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
		if (ger_points >= 40 && ger_points > sov_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Germans</b> have reached [ger_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
	return TRUE

/obj/map_metadata/stalingrad/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall/taiga))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/taiga/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/taiga/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

///////////////////////////////////////////////////////////
////////////////////////////////MINIGRAD///////////////////
///////////////////////////////////////////////////////////

/obj/map_metadata/stalingrad/minigrad
	ID = MAP_SMALLINGRAD
	title = "Central Stalingrad"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/tundra,/area/caribbean/no_mans_land/invisible_wall/tundra/one, /area/caribbean/no_mans_land/invisible_wall/tundra/two)

	faction_distribution_coeffs = list(GERMAN = 0.5, RUSSIAN = 0.5)
	battle_name = "battle of Stalingrad"
	mission_start_message = "<font size=4>All factions have <b>3 minutes</b> to prepare before the ceasefire ends!</font><br><big>Points are added to each team for each minute they control the <b>Train Station, Telephone Central, Hospital, and City Hall</b>.<br>First team to reach <b>40</b> points wins!</font>"

/obj/map_metadata/stalingrad/minigrad/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/german/tank_crew) || istype(J, /datum/job/russian/tank_crew))
		. = FALSE
	else if (J.is_ss_panzer == TRUE)
		. = FALSE
	else if (J.is_occupation == TRUE)
		. = FALSE
	else if (J.is_tanker == TRUE)
		. = FALSE
	else if (J.is_ww2 == TRUE && J.is_reichstag == FALSE)
		. = TRUE
	else if (J.is_reichstag == TRUE)
		. = FALSE
	else
		. = FALSE

/obj/map_metadata/stalingrad/minigrad/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1800 || admin_ended_all_grace_periods)

/obj/map_metadata/stalingrad/minigrad/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1800 || admin_ended_all_grace_periods)

/obj/map_metadata/stalingrad/minigrad/points_check()
	if (processes.ticker.playtime_elapsed > 3000)
		var/c1 = 0
		var/c2 = 0
		var/cust_color = "white"
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/one))
				if (H.faction_text == "GERMAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a1_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a1_control = "Germans"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a1_control = "Soviets"
			cust_color="red"
			sov_points++
		if (a1_control != "none")
			if (a1_control == "Soviets")
				cust_color = "red"
			else
				cust_color = "blue"
			world << "<big><font color='[cust_color]'><b>Telephone Central</b>: [a1_control]</font></big>"
		else
			world << "<big><b>Telephone Central</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/two))
				if (H.faction_text == "GERMAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a2_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a2_control = "Germans"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a2_control = "Soviets"
			cust_color="red"
			sov_points++
		if (a2_control != "none")
			if (a2_control == "Soviets")
				cust_color = "red"
			else
				cust_color = "blue"
			world << "<big><font color='[cust_color]'><b>Train Station</b>: [a2_control]</font></big>"
		else
			world << "<big><b>Train Station</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/three))
				if (H.faction_text == "GERMAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a3_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a3_control = "Germans"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a3_control = "Soviets"
			cust_color="red"
			sov_points++
		if (a3_control != "none")
			if (a3_control == "Soviets")
				cust_color = "red"
			else
				cust_color = "blue"
			world << "<big><font color='[cust_color]'><b>City Hall</b>: [a3_control]</font></big>"
		else
			world << "<big><b>City Hall</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/four))
				if (H.faction_text == "GERMAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a4_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a4_control = "Germans"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a4_control = "Soviets"
			cust_color="red"
			sov_points++
		if (a4_control != "none")
			if (a4_control == "Soviets")
				cust_color = "red"
			else
				cust_color = "blue"
			world << "<big><font color='[cust_color]'><b>Hospital</b>: [a4_control]</font></big>"
		else
			world << "<big><b>Hospital</b>: Nobody</big>"
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Germans: [ger_points]</big>"
	world << "<big>Soviets: [sov_points]</big>"
	spawn(300)
		points_check()

/obj/map_metadata/stalingrad/minigrad/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall/tundra))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/tundra/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/tundra/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE