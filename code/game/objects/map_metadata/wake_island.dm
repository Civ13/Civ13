/obj/map_metadata/wake_island
	ID = MAP_WAKE_ISLAND
	title = "Wake Island"
	lobby_icon_state = "pacific"
	no_winner ="The battle for the city is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 0


	faction_organization = list(
		AMERICAN,
		JAPANESE)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/german/reichstag/roof/objective,
		list(JAPANESE) = /area/caribbean/german/reichstag/roof/objective,
		)
	age = "1941"
	ordinal_age = 6
	faction_distribution_coeffs = list(JAPANESE = 0.65, AMERICAN = 0.35)
	battle_name = "battle of Wake Island"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!</font><br><font size=3>Points are added to each team for each minute they control the <b>Coastal Artillery Batteries, and the Village</b>.<br>First team to reach <b>40</b> points wins!</font>"
	faction1 = AMERICAN
	faction2 = JAPANESE
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Tokkutai Bushi (Koji Tsuruta):1" = "sound/music/tokkutai_bushi.ogg",)
	gamemode = "Area Control"
	var/jap_points = 0
	var/usa_points = 0
	var/a1_control = "none"
	var/a2_control = "none"
	var/a3_control = "none"
/obj/map_metadata/wake_island/New()
	..()
	spawn(3000)
		points_check()

/obj/map_metadata/wake_island/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/american))
		if (J.is_navy == TRUE || (istype(J, /datum/job/american/sailor_ww2)) || (istype(J, /datum/job/american/mp_ww2)) || (istype(J, /datum/job/american/chef_ww2)) || J.is_tanker == TRUE || (istype(J, /datum/job/american/soldier_ww2_filipino)))
			. = FALSE
		else if (J.is_ww2 == TRUE)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/japanese))
		if (J.is_ww2 == TRUE && J.is_navy == TRUE || (istype(J, /datum/job/japanese/ija_ww2_tanker)))
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/wake_island/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/wake_island/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


/obj/map_metadata/wake_island/roundend_condition_def2name(define)
	..()
	switch (define)
		if (AMERICAN)
			return "American"
		if (JAPANESE)
			return "Japanese"
/obj/map_metadata/wake_island/roundend_condition_def2army(define)
	..()
	switch (define)
		if (AMERICAN)
			return "Americans"
		if (JAPANESE)
			return "Japanese"

/obj/map_metadata/wake_island/army2name(army)
	..()
	switch (army)
		if ("Americans")
			return "American"
		if ("Japanese")
			return "Japanese"


/obj/map_metadata/wake_island/cross_message(faction)
	if (faction == JAPANESE)
		return "<font size = 4>Both teams may now cross the invisible wall!</font>"
	else if (faction == AMERICAN)
		return ""
	else
		return ""

/obj/map_metadata/wake_island/reverse_cross_message(faction)
	if (faction == JAPANESE)
		return "<span class = 'userdanger'>Both teams may no longer cross the invisible wall!</span>"
	else if (faction == AMERICAN)
		return ""
	else
		return ""

/obj/map_metadata/wake_island/proc/points_check()
	if (processes.ticker.playtime_elapsed > 6000)
		var/c1 = 0
		var/c2 = 0
		var/prev_control = a1_control
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/houses/nml_two))
				if (H.faction_text == "AMERICAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "JAPANESE" && H.stat == CONSCIOUS)
					c2++
		if (c1+c2<=0 || c1 == c2)
			a1_control = "none"
		else if (c1 > c2)
			a1_control = "Americans"
			usa_points++
		else if (c2 > c1)
			a1_control = "Japanese"
			jap_points++
		if (a1_control != prev_control)
			if (prev_control != "none")
				world << "<font size=3>The [prev_control] have lost the <b>West Artillery Battery!</b><font>"
			else
				world << "<font size=3>The [a1_control] have captured the <b>West Artillery Battery!</b><font>"
		c1 = 0
		c2 = 0
		prev_control = a2_control
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/houses/nml_one))
				if (H.faction_text == "AMERICAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "JAPANESE" && H.stat == CONSCIOUS)
					c2++
		if (c1+c2<=0 || c1 == c2)
			a2_control = "none"
		else if (c1 > c2)
			a2_control = "Americans"
			usa_points++
		else if (c2 > c1)
			a2_control = "Japanese"
			jap_points++
		if (a2_control != prev_control)
			if (prev_control != "none")
				world << "<font size=3>The [prev_control] have lost the <b>East Artillery Battery!</b><font>"
			else
				world << "<font size=3>The [a2_control] have captured the <b>East Artillery Battery!</b><font>"
		c1 = 0
		c2 = 0
		prev_control = a3_control
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/russian/land))
				if (H.faction_text == "AMERICAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "JAPANESE" && H.stat == CONSCIOUS)
					c2++
		if (c1+c2<=0 || c1 == c2)
			a3_control = "none"
		else if (c1 > c2)
			a3_control = "Americans"
			usa_points++
		else if (c2 > c1)
			a3_control = "Japanese"
			jap_points++
		if (a3_control != prev_control)
			if (prev_control != "none")
				world << "<font size=3>The [prev_control] have lost the <b>Village!</b><font>"
			else
				world << "<font size=3>The [a3_control] have captured the <b>Village!</b><font>"
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Americans: [usa_points]</big>"
	world << "<big>Japanese: [jap_points]</big>"
	spawn(300)
		points_check()

/obj/map_metadata/wake_island/update_win_condition()
	if (processes.ticker.playtime_elapsed > 6000)
		if (jap_points < 40 && usa_points < 40)
			return TRUE
		if (jap_points >= 40 && jap_points > usa_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Japanese</b> have reached [jap_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
		if (usa_points >= 40 && usa_points > jap_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Americans</b> have reached [usa_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
	return TRUE

/obj/map_metadata/wake_island/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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