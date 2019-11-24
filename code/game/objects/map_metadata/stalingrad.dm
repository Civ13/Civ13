
/obj/map_metadata/stalingrad
	ID = MAP_STALINGRAD
	title = "Stalingrad (90x250x2)"
	lobby_icon_state = "ww2"
	no_winner ="The battle for the city is still going on."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/taiga)
	respawn_delay = 0
	squad_spawn_locations = FALSE
	faction_organization = list(
		GERMAN,
		RUSSIAN)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(RUSSIAN) = /area/caribbean/german/reichstag/roof/objective,
		list(GERMAN) = /area/caribbean/german/reichstag/roof/objective,
		)
	age = "1942"
	ordinal_age = 6
	faction_distribution_coeffs = list(GERMAN = 0.5, RUSSIAN = 0.5)
	battle_name = "battle of Stalingrad"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!</font><br><font size=3>Points are added to each team for each minute they control the <b>Train Station, Telephone Central and City Hall</b>.<br>First team to reach <b>50</b> points wins!</font>"
	faction1 = GERMAN
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_SNOW, WEATHER_BLIZZARD)
	songs = list(
		"Neue Deutsche Welle (Remix):1" = 'sound/music/neue_deutsche_welle.ogg',)
	gamemode = "Area Control"
	var/sov_points = 0
	var/ger_points = 0
	var/a1_control = "none"
	var/a2_control = "none"
	var/a3_control = "none"
obj/map_metadata/stalingrad/New()
	..()
	spawn(3000)
		points_check()

obj/map_metadata/stalingrad/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_ww2 == TRUE && !J.is_reichstag  && (!J.is_tanker || istype(J, /datum/job/german/tank_crew)))
		. = TRUE
	else
		. = FALSE
	if (J.is_tanker && istype(J, /datum/job/russian))
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

obj/map_metadata/stalingrad/proc/points_check()
	if (processes.ticker.playtime_elapsed > 6000)
		var/c1 = 0
		var/c2 = 0
		var/prev_control = a1_control
		for (var/mob/living/carbon/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/one))
				if (H.faction_text == "GERMAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1+c2<=0 || c1 == c2)
			a1_control = "none"
		else if (c1 > c2)
			a1_control = "Germans"
			ger_points++
		else if (c2 > c1)
			a1_control = "Soviets"
			sov_points++
		if (a1_control != prev_control)
			if (prev_control != "none")
				world << "<font size=3>The [prev_control] have lost the <b>Telephone Central!</b><font>"
			else
				world << "<font size=3>The [a1_control] have captured the <b>Telephone Central!</b><font>"
		c1 = 0
		c2 = 0
		prev_control = a2_control
		for (var/mob/living/carbon/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/two))
				if (H.faction_text == "GERMAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1+c2<=0 || c1 == c2)
			a2_control = "none"
		else if (c1 > c2)
			a2_control = "Germans"
			ger_points++
		else if (c2 > c1)
			a2_control = "Soviets"
			sov_points++
		if (a2_control != prev_control)
			if (prev_control != "none")
				world << "<font size=3>The [prev_control] have lost the <b>Train Station!</b><font>"
			else
				world << "<font size=3>The [a2_control] have captured the <b>Train Station!</b><font>"
		c1 = 0
		c2 = 0
		prev_control = a3_control
		for (var/mob/living/carbon/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/three))
				if (H.faction_text == "GERMAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1+c2<=0 || c1 == c2)
			a3_control = "none"
		else if (c1 > c2)
			a3_control = "Germans"
			ger_points++
		else if (c2 > c1)
			a3_control = "Soviets"
			sov_points++
		if (a3_control != prev_control)
			if (prev_control != "none")
				world << "<font size=3>The [prev_control] have lost the <b>City Hall!</b><font>"
			else
				world << "<font size=3>The [a3_control] have captured the <b>City Hall!</b><font>"
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Germans: [ger_points]</big>"
	world << "<big>Soviets: [sov_points]</big>"
	spawn(300)
		points_check()

/obj/map_metadata/stalingrad/update_win_condition()
	if (processes.ticker.playtime_elapsed > 6000)
		if (sov_points < 50 && ger_points < 50)
			return TRUE
		if (sov_points >= 50 && sov_points > ger_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Soviets</b> have reached [sov_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
		if (ger_points >= 50 && ger_points > sov_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Germans</b> have reached [ger_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
	return TRUE
