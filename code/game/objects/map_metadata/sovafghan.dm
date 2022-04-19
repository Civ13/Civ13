/obj/map_metadata/sovafghan
	ID = MAP_SOVAFGHAN
	title = "Soviet-Afghan War"
	no_winner ="The region of Kandahar is still contested."
	lobby_icon_state = "sovafghan"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/one, /area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 600
	has_hunger = TRUE

	faction_organization = list(
		RUSSIAN,
		CIVILIAN,
		ARAB)

	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/british,
		list(ARAB) = /area/caribbean/russian/land/inside/command,
		)
	age = "1984"
	ordinal_age = 7
	faction_distribution_coeffs = list(RUSSIAN = 0.4, CIVILIAN = 0.5, ARAB = 0.5)
	battle_name = "Soviet Afghan War"
	mission_start_message = "<font size=4>The <b><font color ='red'>Soviets</font></b>, along with the <b><font color ='green'>DRA</font></b>, have to remain in control of the Kandahar province. <br>The <b><font color ='black'>Mujahideen</font></b> must get rid of the communist oppressors in the region by capturing and holding their outposts and/or by killing their officers. <b>The faction with the most points (<b>60</b>) wins!</b><br></font>"
	faction1 = ARAB
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"Swallowing Dust:1" = "sound/music/swallowingdust.ogg")
	gamemode = "Afghan"
	artillery_count = 3
	var/sov_points = 0
	var/muj_points = 0
	var/a1_control = "DRA"
	var/a2_control = "DRA"
	var/a3_control = "DRA"
	var/a4_control = "DRA"
	is_RP = TRUE
	var/gracedown1 = TRUE

/obj/map_metadata/sovafghan/New()
	..()
	spawn(3000)
		points_check()

/obj/map_metadata/sovafghan/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_afghan)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/sovafghan/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 6000 || admin_ended_all_grace_periods)

/obj/map_metadata/sovafghan/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 6000 || admin_ended_all_grace_periods)

/obj/map_metadata/sovafghan/roundend_condition_def2name(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Soviet Army"
		if (ARAB)
			return "Mujahideen"
		if (CIVILIAN)
			return "DRA"

/obj/map_metadata/sovafghan/roundend_condition_def2army(define)
	..()
	switch (define)
		if (RUSSIAN)
			return "Soviet Army"
		if (ARAB)
			return "Mujahideen"
		if (CIVILIAN)
			return "DRA"

/obj/map_metadata/sovafghan/army2name(army)
	..()
	switch (army)
		if ("Soviet Army")
			return "Soviet Army"
		if ("ARAB")
			return "Mujahideen"
		if ("CIVILIAN")
			return "DRA"

/obj/map_metadata/sovafghan/cross_message(faction)
	if (faction == ARAB)
		return "<font size = 4>The grace wall is down!</font>"
	else if (faction == CIVILIAN)
		return ""
	else if (faction == RUSSIAN)
		return "<font size = 4>The grace wall is down!</font>"
	else
		return ""

/obj/map_metadata/sovafghan/reverse_cross_message(faction)
	if (faction == ARAB)
		return "<font size = 4>The grace wall is up!</font>"
	else if (faction == CIVILIAN)
		return ""
	else if (faction == RUSSIAN)
		return "<font size = 4>The grace wall is up!</font>"
	else
		return ""

/obj/map_metadata/sovafghan/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (caribbean_blocking_area_types.Find(A.type))
		if (H.faction_text == faction2 || H.faction_text == faction1 && !H.original_job.is_muj)
			return !faction1_can_cross_blocks()
		else if (H.original_job.is_muj)
			return !faction2_can_cross_blocks()
		else
			return FALSE
	return FALSE

/obj/map_metadata/sovafghan/proc/points_check()
	if (processes.ticker.playtime_elapsed > 1200)
		var/c1 = 0
		var/c2 = 0
		var/c3 = 0
		var/cust_color = "white"
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/one))
				if (H.faction_text == "ARAB" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
				else if ((H.faction_text == "CIVILIAN" && H.original_job.is_dra == TRUE) && H.stat == CONSCIOUS)
					c3++
		if ((c1 == c2 || c1 == c3) && c1 != 0)
			a1_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a1_control = "Mujahideen"
			cust_color="black"
			muj_points++
		else if (c2 > c1 || c2 > c3)
			a1_control = "Soviets"
			cust_color="red"
			sov_points++
		else if (c3 > c1 || c3 > c2)
			a1_control = "DRA"
			cust_color="green"
			sov_points++
		if (a1_control != "none")
			if (a1_control == "Soviets")
				cust_color = "red"
			else if (a1_control == "Mujahideen")
				cust_color = "black"
			else if (a1_control == "DRA")
				cust_color = "green"
			else
				cust_color = "white"
			world << "<big><font color='[cust_color]'><b>South West Village Outpost</b>: [a1_control]</font></big>"
		else
			world << "<big><b>South West Village Outpost</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		c3 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/two))
				if (H.faction_text == "ARAB" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
				else if ((H.faction_text == "CIVILIAN" && H.original_job.is_dra == TRUE) && H.stat == CONSCIOUS)
					c3++
		if ((c1 == c2 || c1 == c3) && c1 != 0)
			a2_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a2_control = "Mujahideen"
			cust_color="black"
			muj_points++
		else if (c2 > c1 || c2 > c3)
			a2_control = "Soviets"
			cust_color="red"
			sov_points++
		else if (c3 > c1 || c3 > c2)
			a2_control = "DRA"
			cust_color="green"
			sov_points++
		if (a2_control != "none")
			if (a2_control == "Soviets")
				cust_color = "red"
			else if (a2_control == "Mujahideen")
				cust_color = "black"
			else if (a2_control == "DRA")
				cust_color = "green"
			else
				cust_color = "white"
			world << "<big><font color='[cust_color]'><b>South Border Checkpoint</b>: [a2_control]</font></big>"
		else
			world << "<big><b>South Border Checkpoint</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		c3 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/three))
				if (H.faction_text == "ARAB" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
				else if ((H.faction_text == "CIVILIAN" && H.original_job.is_dra == TRUE) && H.stat == CONSCIOUS)
					c3++
		if ((c1 == c2 || c1 == c3) && c1 != 0)
			a3_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a3_control = "Mujahideen"
			cust_color="black"
			muj_points++
		else if (c2 > c1 || c2 > c3)
			a3_control = "Soviets"
			cust_color="red"
			sov_points++
		else if (c3 > c1 || c3 > c2)
			a3_control = "DRA"
			cust_color="green"
			sov_points++
		if (a3_control != "none")
			if (a1_control == "Soviets")
				cust_color = "red"
			else if (a3_control == "Mujahideen")
				cust_color = "black"
			else if (a3_control == "DRA")
				cust_color = "green"
			else
				cust_color = "white"
			world << "<big><font color='[cust_color]'><b>Palace</b>: [a3_control]</font></big>"
		else
			world << "<big><b>Palace</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		c3 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/four))
				if (H.faction_text == "ARAB" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
				else if ((H.faction_text == "CIVILIAN" && H.original_job.is_dra == TRUE) && H.stat == CONSCIOUS)
					c3++
		if ((c1 == c2 || c1 == c3) && c1 != 0)
			a4_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a4_control = "Mujahideen"
			cust_color="black"
			muj_points++
		else if (c2 > c1 || c2 > c3)
			a4_control = "Soviets"
			cust_color="red"
			sov_points++
		else if (c3 > c1 || c3 > c2)
			a4_control = "DRA"
			cust_color="green"
			sov_points++
		if (a4_control != "none")
			if (a4_control == "Soviets")
				cust_color = "red"
			else if (a4_control == "Mujahideen")
				cust_color = "black"
			else if (a4_control == "DRA")
				cust_color = "green"
			else
				cust_color = "white"
			world << "<big><font color='[cust_color]'><b>North West Village Outpost</b>: [a4_control]</font></big>"
		else
			world << "<big><b>North West Village Outpost</b>: Nobody</big>"
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Mujahideen: [muj_points]</big>"
	world << "<big>Soviets and DRA: [sov_points]</big>"
	spawn(600)
		points_check()

/obj/map_metadata/sovafghan/update_win_condition()
	if (processes.ticker.playtime_elapsed > 3000)
		if (sov_points < 60 && muj_points < 60)
			return TRUE
		if (sov_points >= 60 && sov_points > muj_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b><font color ='red'>Soviets</font></b> and <b><font color ='green'>DRA</font></b> have reached [sov_points] points and won! The Kandahar region remains under the <b><font color ='green'>DRA</font></b> control"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
		if (muj_points >= 60 && muj_points > sov_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b><font color ='black'>Mujahideen</font></b> have reached [muj_points] points and won! The Kandahar province is under their control!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
	return TRUE

/obj/map_metadata/sovafghan/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
			if (H.faction_text == "CIVILIAN")
				return TRUE
		else
			return !faction2_can_cross_blocks()
	return FALSE