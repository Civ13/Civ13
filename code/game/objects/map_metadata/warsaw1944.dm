
/obj/map_metadata/warsaw
	ID = MAP_WARSAW
	title = "Warsaw 1944"
	lobby_icon = "icons/lobby/warsawup.png"
	no_winner ="The battle for the city is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/inside/one)
	respawn_delay = 0

	faction_organization = list(
		GERMAN,
		POLISH)

	roundend_condition_sides = list(
		list(POLISH) = /area/caribbean/german/reichstag/roof/objective,
		list(GERMAN) = /area/caribbean/german/reichstag/roof/objective,
		)
	age = "1944"
	ordinal_age = 6
	faction_distribution_coeffs = list(GERMAN = 0.5, POLAND = 0.5)
	battle_name = "The warsaw uprising"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!</font><br><big>Points are added to each team for each minute they control the <b>Train Station, Communication station and warsaw housing</b>.<br>First team to reach <b>80</b> points wins!</font>"
	faction1 = GERMAN
	faction2 = POLISH
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"Song of The Warsaw Uprising - Boys strong as steel:1" = "sound/music/boysstrongassteel.ogg",)
	gamemode = "Area Control"
	var/pol_points = 0
	var/ger_points = 0
	var/a1_control = "none"
	var/a2_control = "none"
	var/a3_control = "none"
	var/a4_control = "none"
	grace_wall_timer = 3000
/obj/map_metadata/warsaw/New()
	..()
	spawn(3000)
		points_check()

/obj/map_metadata/warsaw/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/german/tank_crew))
		. = TRUE
	else if (J.is_warsawger == TRUE)
		. = TRUE
	else if (J.is_warpol == TRUE)
		. = TRUE
	else if (J.is_tanker == TRUE)
		. = FALSE
	else if (J.is_ww2 == TRUE && J.is_reichstag == FALSE)
		. = FALSE
	else if (J.is_reichstag == TRUE)
		. = FALSE
	else
		. = FALSE

/obj/map_metadata/warsaw/roundend_condition_def2name(define)
	..()
	switch (define)
		if (GERMAN)
			return "German"
		if (POLISH)
			return "Poland"
/obj/map_metadata/warsaw/roundend_condition_def2army(define)
	..()
	switch (define)
		if (GERMAN)
			return "Germans"
		if (POLISH)
			return "Polish"

/obj/map_metadata/warsaw/army2name(army)
	..()
	switch (army)
		if ("Germans")
			return "German"
		if ("Polish")
			return "Poland"


/obj/map_metadata/warsaw/cross_message(faction)
	if (faction == POLISH)
		return "<font size = 4>Both teams may now cross the invisible wall!</font>"
	else if (faction == GERMAN)
		return ""
	else
		return ""

/obj/map_metadata/warsaw/reverse_cross_message(faction)
	if (faction == POLISH)
		return "<span class = 'userdanger'>Both teams may no longer cross the invisible wall!</span>"
	else if (faction == GERMAN)
		return ""
	else
		return ""

/obj/map_metadata/warsaw/proc/points_check()
	var/cust_color = "white"
	if (processes.ticker.playtime_elapsed > 3600)
		var/c1 = 0
		var/c2 = 0
		var/prev_control = a1_control
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/one))
				if (H.faction_text == "GERMAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "POLAND" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a1_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a1_control = "Germans"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a1_control = "Polish"
			cust_color="red"
			pol_points++
		if (a1_control != prev_control)
			if (prev_control != "none")
				world << "<big><font color='[cust_color]'>[prev_control]</font> lost the <b>Communication station</b>!</big>"
			else
				world << "<big><font color='[cust_color]'>[a1_control]</font> captured the <b>Communication station</b>!</big>"
		c1 = 0
		c2 = 0
		prev_control = a2_control
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/two))
				if (H.faction_text == "GERMAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "POLAND" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a2_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a2_control = "Germans"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a2_control = "Polish"
			cust_color="red"
			pol_points++
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
				else if (H.faction_text == "POLAND" && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a3_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a3_control = "Germans"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a3_control = "Polish"
			cust_color="red"
			pol_points++
		if (a3_control != prev_control)
			if (prev_control != "none")
				world << "<big><font color='[cust_color]'>[prev_control]</font> lost the <b>Warsaw housing</b>!</big>"
			else
				world << "<big><font color='[cust_color]'>[a3_control]</font> captured the <b>Warsaw housing</b>!</big>"
	if (a1_control == "Polish")
		cust_color = "red"
	else
		cust_color = "blue"
	world << "<big><font color='[cust_color]'><b>Communication station</b>: [a1_control]</font></big>"
	if (a2_control == "Polish")
		cust_color = "red"
	else
		cust_color = "blue"
	world << "<big><font color='[cust_color]'><b>Train Station</b>: [a2_control]</font></big>"
	if (a3_control == "Polish")
		cust_color = "red"
	else
		cust_color = "blue"
	world << "<big><font color='[cust_color]'><b>Warsaw housing</b>: [a3_control]</font></big>"
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Germans: [ger_points]</big>"
	world << "<big>Polish: [pol_points]</big>"
	spawn(300)
		points_check()

/obj/map_metadata/warsaw/update_win_condition()
	if (processes.ticker.playtime_elapsed > 6000)
		if (pol_points < 80 && ger_points < 80)
			return TRUE
		if (pol_points >= 80 && pol_points > ger_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Polish</b> have reached [pol_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
		if (ger_points >= 80 && ger_points > pol_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Germans</b> have reached [ger_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
	return TRUE

/obj/map_metadata/warsaw/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/inside/one))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE